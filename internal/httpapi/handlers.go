package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime"
	"mime/multipart"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	meiliidx "cvrepo/internal/search/meili"
	fsstorage "cvrepo/internal/storage/fs"
	pgstore "cvrepo/internal/store/pg"
)

const maxUploadBytes = 32 << 20 // 32 MiB

// BatchLimits caps multipart batch uploads (POST /v1/cvs/batch). Zero values in NewHandler are replaced with defaults.
type BatchLimits struct {
	MaxRequestBytes int64
	MaxFileBytes    int64
	MaxFiles        int
}

type Handler struct {
	store       *pgstore.Store
	fs          *fsstorage.Store
	idx         *meiliidx.Index
	batchLimits BatchLimits
}

func NewHandler(store *pgstore.Store, fs *fsstorage.Store, idx *meiliidx.Index, batch BatchLimits) *Handler {
	if batch.MaxRequestBytes <= 0 {
		batch.MaxRequestBytes = 256 << 20
	}
	if batch.MaxFileBytes <= 0 {
		batch.MaxFileBytes = 32 << 20
	}
	if batch.MaxFiles <= 0 {
		batch.MaxFiles = 100
	}
	return &Handler{store: store, fs: fs, idx: idx, batchLimits: batch}
}

type cvJSON struct {
	ID               string  `json:"id"`
	Title            string  `json:"title"`
	OriginalFilename string  `json:"original_filename"`
	ContentType      string  `json:"content_type"`
	SizeBytes        int64   `json:"size_bytes"`
	SHA256           string  `json:"sha256"`
	Status           string  `json:"status"`
	ParseError       *string `json:"parse_error,omitempty"`
	TextSnippet      *string `json:"text_snippet,omitempty"`
	CreatedAt        string  `json:"created_at"`
	UpdatedAt        string  `json:"updated_at"`
}

func toJSON(cv *pgstore.CV, includeSnippet bool) cvJSON {
	j := cvJSON{
		ID:               cv.ID.String(),
		Title:            cv.Title,
		OriginalFilename: cv.OriginalFilename,
		ContentType:      cv.ContentType,
		SizeBytes:        cv.SizeBytes,
		SHA256:           cv.SHA256,
		Status:           string(cv.Status),
		ParseError:       cv.ParseError,
		CreatedAt:        cv.CreatedAt.UTC().Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt:        cv.UpdatedAt.UTC().Format("2006-01-02T15:04:05Z07:00"),
	}
	if includeSnippet && cv.ExtractedText != nil && *cv.ExtractedText != "" {
		s := snippet(*cv.ExtractedText, 500)
		j.TextSnippet = &s
	}
	return j
}

func snippet(s string, maxRunes int) string {
	if maxRunes <= 0 {
		return ""
	}
	if utf8.RuneCountInString(s) <= maxRunes {
		return s
	}
	var b strings.Builder
	n := 0
	for _, r := range s {
		if n >= maxRunes {
			break
		}
		b.WriteRune(r)
		n++
	}
	b.WriteString("…")
	return b.String()
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func contentTypeBase(s string) string {
	ct := strings.TrimSpace(s)
	if i := strings.Index(ct, ";"); i >= 0 {
		ct = ct[:i]
	}
	return strings.ToLower(strings.TrimSpace(ct))
}

func isPDFFile(hdr *multipart.FileHeader) bool {
	ct := contentTypeBase(hdr.Header.Get("Content-Type"))
	if ct == "application/pdf" {
		return true
	}
	if ct == "application/octet-stream" || ct == "binary/octet-stream" || ct == "" {
		return strings.EqualFold(filepath.Ext(hdr.Filename), ".pdf")
	}
	return false
}

func (h *Handler) persistUploadedPDF(ctx context.Context, originalFilename, contentType string, r io.Reader, title string, maxBytes int64) (*pgstore.CV, error) {
	id := uuid.New()
	storageKey, sha256hex, size, err := h.fs.SavePDF(id, originalFilename, io.LimitReader(r, maxBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to save file")
	}
	cv := &pgstore.CV{
		ID:               id,
		Title:            title,
		OriginalFilename: originalFilename,
		ContentType:      contentType,
		StorageKey:       storageKey,
		SHA256:           sha256hex,
		SizeBytes:        size,
		Status:           pgstore.StatusPending,
	}
	if cv.ContentType == "" {
		cv.ContentType = "application/pdf"
	}
	if err := h.store.Create(ctx, cv); err != nil {
		_ = h.fs.Remove(storageKey)
		return nil, fmt.Errorf("failed to save metadata")
	}
	return cv, nil
}

// safeInlineFilename returns an ASCII-only basename safe for Content-Disposition filename=.
func safeInlineFilename(name string) string {
	base := filepath.Base(name)
	if base == "" || base == "." || base == string(filepath.Separator) {
		base = "document.pdf"
	}
	var b strings.Builder
	for _, r := range base {
		if r < 32 || r == '"' || r == '\\' {
			continue
		}
		if r > 127 {
			continue
		}
		b.WriteRune(r)
	}
	s := b.String()
	if s == "" {
		return "document.pdf"
	}
	return s
}

func (h *Handler) PostCV(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(maxUploadBytes); err != nil {
		writeError(w, http.StatusBadRequest, "invalid multipart form")
		return
	}
	file, hdr, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, "file field required")
		return
	}
	defer file.Close()

	title := strings.TrimSpace(r.FormValue("title"))
	if title == "" {
		title = strings.TrimSpace(hdr.Filename)
	}
	if title == "" {
		title = "Untitled"
	}

	cv, err := h.persistUploadedPDF(r.Context(), hdr.Filename, hdr.Header.Get("Content-Type"), file, title, maxUploadBytes)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, toJSON(cv, false))
}

type batchItemJSON struct {
	Filename string `json:"filename"`
	ID       string `json:"id,omitempty"`
	Status   string `json:"status,omitempty"`
	Error    string `json:"error,omitempty"`
}

func (h *Handler) PostCVBatch(w http.ResponseWriter, r *http.Request) {
	maxReq := h.batchLimits.MaxRequestBytes
	if err := r.ParseMultipartForm(maxReq); err != nil {
		writeError(w, http.StatusBadRequest, "invalid multipart form")
		return
	}
	fhs := r.MultipartForm.File["files"]
	if len(fhs) == 0 {
		writeError(w, http.StatusBadRequest, "files field required (one or more PDFs)")
		return
	}
	maxFiles := h.batchLimits.MaxFiles
	if len(fhs) > maxFiles {
		writeError(w, http.StatusBadRequest, fmt.Sprintf("too many files (max %d)", maxFiles))
		return
	}
	perFile := h.batchLimits.MaxFileBytes

	results := make([]batchItemJSON, 0, len(fhs))
	created, failed := 0, 0
	for _, hdr := range fhs {
		name := hdr.Filename
		if name == "" {
			name = "unnamed"
		}
		if !isPDFFile(hdr) {
			results = append(results, batchItemJSON{Filename: name, Error: "not a PDF"})
			failed++
			continue
		}
		f, err := hdr.Open()
		if err != nil {
			results = append(results, batchItemJSON{Filename: name, Error: "failed to read file"})
			failed++
			continue
		}
		title := strings.TrimSpace(hdr.Filename)
		if title == "" {
			title = "Untitled"
		}
		cv, err := h.persistUploadedPDF(r.Context(), hdr.Filename, hdr.Header.Get("Content-Type"), f, title, perFile)
		_ = f.Close()
		if err != nil {
			results = append(results, batchItemJSON{Filename: name, Error: err.Error()})
			failed++
			continue
		}
		results = append(results, batchItemJSON{Filename: name, ID: cv.ID.String(), Status: string(cv.Status)})
		created++
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"created": created,
		"failed":  failed,
		"results": results,
	})
}

func (h *Handler) ListCVs(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	list, total, err := h.store.List(r.Context(), limit, offset)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list failed")
		return
	}
	out := make([]cvJSON, 0, len(list))
	for i := range list {
		out = append(out, toJSON(&list[i], false))
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"items": out,
		"total": total,
	})
}

func (h *Handler) GetCV(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	cv, err := h.store.GetByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgstore.ErrNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "get failed")
		return
	}
	writeJSON(w, http.StatusOK, toJSON(cv, true))
}

func (h *Handler) GetCVFile(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	cv, err := h.store.GetByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgstore.ErrNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "get failed")
		return
	}
	f, err := h.fs.Open(cv.StorageKey)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "file unavailable")
		return
	}
	defer f.Close()
	fi, err := f.Stat()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "file unavailable")
		return
	}
	ct := cv.ContentType
	if ct == "" {
		ct = "application/pdf"
	}
	w.Header().Set("Content-Type", ct)
	disp := mime.FormatMediaType("inline", map[string]string{
		"filename": safeInlineFilename(cv.OriginalFilename),
	})
	if disp == "" {
		disp = `inline; filename="document.pdf"`
	}
	w.Header().Set("Content-Disposition", disp)
	http.ServeContent(w, r, cv.OriginalFilename, fi.ModTime(), f)
}

func (h *Handler) DeleteCV(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	cv, err := h.store.GetByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgstore.ErrNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "get failed")
		return
	}
	_ = h.idx.Delete(r.Context(), id)
	if err := h.fs.Remove(cv.StorageKey); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to remove file from storage")
		return
	}
	if err := h.store.DeleteRow(r.Context(), id); err != nil {
		if errors.Is(err, pgstore.ErrNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "delete failed")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) Search(w http.ResponseWriter, r *http.Request) {
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	if q == "" {
		writeJSON(w, http.StatusOK, map[string]any{"hits": []any{}, "query": q})
		return
	}
	limit, _ := strconv.ParseInt(r.URL.Query().Get("limit"), 10, 64)
	res, err := h.idx.Search(r.Context(), q, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "search failed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"query": q,
		"hits":  res.Hits,
	})
}
