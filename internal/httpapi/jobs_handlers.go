package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	pgstore "cvrepo/internal/store/pg"
)

const (
	// maxChatContexts caps how many CVs are sent to the model per chat call.
	maxChatContexts = 8
	// maxChatContextChars caps per-CV text length (in runes) to bound prompt size.
	maxChatContextChars = 4000
)

// truncateRunes returns at most n runes of s, appending an ellipsis when cut.
func truncateRunes(s string, n int) string {
	if n <= 0 {
		return ""
	}
	runes := []rune(s)
	if len(runes) <= n {
		return s
	}
	return string(runes[:n]) + "…"
}

type jobJSON struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	JDText    string `json:"jd_text"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
}

func toJobJSON(j *pgstore.Job) jobJSON {
	return jobJSON{
		ID:        j.ID.String(),
		Title:     j.Title,
		JDText:    j.JDText,
		CreatedAt: j.CreatedAt.UTC().Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt: j.UpdatedAt.UTC().Format("2006-01-02T15:04:05Z07:00"),
	}
}

func (h *Handler) PostJob(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Title  string `json:"title"`
		JDText string `json:"jd_text"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json body")
		return
	}
	jd := strings.TrimSpace(body.JDText)
	if jd == "" {
		writeError(w, http.StatusBadRequest, "jd_text is required")
		return
	}
	title := strings.TrimSpace(body.Title)
	if title == "" {
		title = "Untitled role"
	}
	job := &pgstore.Job{
		Kind:   pgstore.JobKindDefinition,
		Title:  title,
		JDText: jd,
		Status: pgstore.CampaignActive,
	}
	if err := h.store.CreateJob(r.Context(), job); err != nil {
		writeError(w, http.StatusInternalServerError, "create job failed")
		return
	}
	h.maybeEnqueueRank(r.Context(), job.ID, job.Status, "")
	writeJSON(w, http.StatusCreated, toJobJSON(job))
}

func (h *Handler) PutJob(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	if _, err := h.store.GetJobByKind(r.Context(), id, pgstore.JobKindDefinition); err != nil {
		if errors.Is(err, pgstore.ErrJobNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "get job failed")
		return
	}
	var body struct {
		Title  string `json:"title"`
		JDText string `json:"jd_text"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json body")
		return
	}
	jd := strings.TrimSpace(body.JDText)
	if jd == "" {
		writeError(w, http.StatusBadRequest, "jd_text is required")
		return
	}
	title := strings.TrimSpace(body.Title)
	if title == "" {
		title = "Untitled role"
	}
	if err := h.store.UpdateJobContent(r.Context(), id, title, jd); err != nil {
		if errors.Is(err, pgstore.ErrJobNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "update job failed")
		return
	}
	updated, err := h.store.GetJobByKind(r.Context(), id, pgstore.JobKindDefinition)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "get job failed")
		return
	}
	writeJSON(w, http.StatusOK, toJobJSON(updated))
}

func (h *Handler) DeleteJob(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.store.DeleteJob(r.Context(), id); err != nil {
		if errors.Is(err, pgstore.ErrJobNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "delete job failed")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) ListJobs(w http.ResponseWriter, r *http.Request) {
	jobs, err := h.store.ListJobs(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list jobs failed")
		return
	}
	out := make([]jobJSON, 0, len(jobs))
	for i := range jobs {
		out = append(out, toJobJSON(&jobs[i]))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

func (h *Handler) GetJob(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	job, err := h.store.GetJobByKind(r.Context(), id, pgstore.JobKindDefinition)
	if err != nil {
		if errors.Is(err, pgstore.ErrJobNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "get job failed")
		return
	}
	writeJSON(w, http.StatusOK, toJobJSON(job))
}

func (h *Handler) PostJobRank(w http.ResponseWriter, r *http.Request) {
	if h.pipeline == nil {
		writeError(w, http.StatusServiceUnavailable, "AI pipeline not configured")
		return
	}
	jobID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	if _, err := h.store.GetJobByKind(r.Context(), jobID, pgstore.JobKindDefinition); err != nil {
		if errors.Is(err, pgstore.ErrJobNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "get job failed")
		return
	}
	queued, err := h.store.EnqueueRankTasksForJob(r.Context(), jobID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "enqueue rank tasks failed")
		return
	}
	writeJSON(w, http.StatusAccepted, map[string]any{
		"job_id": jobID.String(),
		"queued": queued,
	})
}

func (h *Handler) GetJobRankStatus(w http.ResponseWriter, r *http.Request) {
	jobID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	if _, err := h.store.GetJobByKind(r.Context(), jobID, pgstore.JobKindDefinition); err != nil {
		if errors.Is(err, pgstore.ErrJobNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "get job failed")
		return
	}
	st, err := h.store.RankStatusForJob(r.Context(), jobID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "rank status failed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"job_id":     jobID.String(),
		"pending":    st.Pending,
		"processing": st.Processing,
		"done":       st.Done,
		"failed":     st.Failed,
	})
}

// PostJDImprove uses the AI pipeline to rewrite/structure a job description
// (or draft one from a title) without persisting anything.
func (h *Handler) PostJDImprove(w http.ResponseWriter, r *http.Request) {
	if h.pipeline == nil {
		writeError(w, http.StatusServiceUnavailable, "AI pipeline not configured")
		return
	}
	var body struct {
		Title       string `json:"title"`
		JDText      string `json:"jd_text"`
		Instruction string `json:"instruction"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json body")
		return
	}
	title := strings.TrimSpace(body.Title)
	jd := strings.TrimSpace(body.JDText)
	if title == "" && jd == "" {
		writeError(w, http.StatusBadRequest, "provide a title or job description to improve")
		return
	}
	res, err := h.pipeline.ImproveJD(r.Context(), title, jd, strings.TrimSpace(body.Instruction))
	if err != nil {
		writeError(w, http.StatusBadGateway, "ai improve failed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"title":            res.Title,
		"jd_text":          res.JDText,
		"summary":          res.Summary,
		"highlights":       res.Highlights,
		"suggested_skills": res.SuggestedSkills,
	})
}

func (h *Handler) GetJobFeed(w http.ResponseWriter, r *http.Request) {
	h.writeRoleFeed(w, r, pgstore.JobKindDefinition)
}

func (h *Handler) writeRoleFeed(w http.ResponseWriter, r *http.Request, kind pgstore.JobKind) {
	jobID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	if _, err := h.store.GetJobByKind(r.Context(), jobID, kind); err != nil {
		if errors.Is(err, pgstore.ErrJobNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "get role failed")
		return
	}
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	items, total, err := h.store.ListScoresByJob(r.Context(), jobID, limit, offset)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "feed failed")
		return
	}
	out := make([]map[string]any, 0, len(items))
	for _, it := range items {
		var profile any
		if len(it.CV.Profile) > 0 {
			_ = json.Unmarshal(it.CV.Profile, &profile)
		}
		var subscores any
		_ = json.Unmarshal(it.Score.Subscores, &subscores)
		var evidence any
		_ = json.Unmarshal(it.Score.Evidence, &evidence)
		var onePager any
		_ = json.Unmarshal(it.Score.OnePager, &onePager)
		out = append(out, map[string]any{
			"cv":        toJSON(&it.CV, false),
			"profile":   profile,
			"score":     it.Score.Score,
			"subscores": subscores,
			"evidence":  evidence,
			"one_pager": onePager,
			"scored_at": it.Score.CreatedAt.UTC().Format("2006-01-02T15:04:05Z07:00"),
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"items": out,
		"total": total,
	})
}

func (h *Handler) PostReaction(w http.ResponseWriter, r *http.Request) {
	cvID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	if _, err := h.store.GetByID(r.Context(), cvID); err != nil {
		if errors.Is(err, pgstore.ErrNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "get failed")
		return
	}
	var body struct {
		Action string  `json:"action"`
		JobID  *string `json:"job_id"`
		ExecID *string `json:"exec_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json body")
		return
	}
	action := strings.TrimSpace(body.Action)
	if action != "shortlist" && action != "pass" && action != "star" && action != "like" {
		writeError(w, http.StatusBadRequest, "action must be shortlist, pass, star, or like")
		return
	}
	var jobID *uuid.UUID
	if body.JobID != nil && strings.TrimSpace(*body.JobID) != "" {
		jid, err := uuid.Parse(strings.TrimSpace(*body.JobID))
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid job_id")
			return
		}
		jobID = &jid
	}
	react := &pgstore.Reaction{CVID: cvID, JobID: jobID, ExecID: body.ExecID, Action: action}
	if err := h.store.AddReaction(r.Context(), react); err != nil {
		writeError(w, http.StatusInternalServerError, "add reaction failed")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{
		"id":     react.ID.String(),
		"action": react.Action,
	})
}

func reactionToJSON(r *pgstore.Reaction) map[string]any {
	out := map[string]any{
		"id":         r.ID.String(),
		"cv_id":      r.CVID.String(),
		"action":     r.Action,
		"created_at": r.CreatedAt.UTC().Format("2006-01-02T15:04:05Z07:00"),
	}
	if r.JobID != nil {
		out["job_id"] = r.JobID.String()
	} else {
		out["job_id"] = nil
	}
	if r.ExecID != nil {
		out["exec_id"] = *r.ExecID
	} else {
		out["exec_id"] = "anonymous"
	}
	return out
}

func (h *Handler) ListReactions(w http.ResponseWriter, r *http.Request) {
	execID := strings.TrimSpace(r.URL.Query().Get("exec_id"))
	if execID == "" {
		writeError(w, http.StatusBadRequest, "exec_id is required")
		return
	}
	var jobID *uuid.UUID
	if raw := strings.TrimSpace(r.URL.Query().Get("job_id")); raw != "" {
		jid, err := uuid.Parse(raw)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid job_id")
			return
		}
		jobID = &jid
	}
	var action *string
	if raw := strings.TrimSpace(r.URL.Query().Get("action")); raw != "" {
		if raw != "shortlist" && raw != "pass" && raw != "star" && raw != "like" {
			writeError(w, http.StatusBadRequest, "action must be shortlist, pass, star, or like")
			return
		}
		action = &raw
	}
	list, err := h.store.ListReactionsByExec(r.Context(), execID, jobID, action)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list reactions failed")
		return
	}
	items := make([]map[string]any, 0, len(list))
	for i := range list {
		items = append(items, reactionToJSON(&list[i]))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) DeleteReaction(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	execID := strings.TrimSpace(r.URL.Query().Get("exec_id"))
	if execID == "" {
		writeError(w, http.StatusBadRequest, "exec_id is required")
		return
	}
	if err := h.store.DeleteReaction(r.Context(), id, execID); err != nil {
		if errors.Is(err, pgstore.ErrNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "delete reaction failed")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) PostComment(w http.ResponseWriter, r *http.Request) {
	cvID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	if _, err := h.store.GetByID(r.Context(), cvID); err != nil {
		if errors.Is(err, pgstore.ErrNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "get failed")
		return
	}
	var body struct {
		Author string `json:"author"`
		Body   string `json:"body"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json body")
		return
	}
	text := strings.TrimSpace(body.Body)
	if text == "" {
		writeError(w, http.StatusBadRequest, "body is required")
		return
	}
	author := strings.TrimSpace(body.Author)
	if author == "" {
		author = "anonymous"
	}
	c := &pgstore.Comment{CVID: cvID, Author: author, Body: text}
	if err := h.store.AddComment(r.Context(), c); err != nil {
		writeError(w, http.StatusInternalServerError, "add comment failed")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{
		"id":     c.ID.String(),
		"author": c.Author,
		"body":   c.Body,
	})
}

func (h *Handler) PostChat(w http.ResponseWriter, r *http.Request) {
	if h.pipeline == nil {
		writeError(w, http.StatusServiceUnavailable, "AI pipeline not configured")
		return
	}
	var body struct {
		Query string  `json:"query"`
		JobID *string `json:"job_id"`
		Limit int     `json:"limit"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json body")
		return
	}
	query := strings.TrimSpace(body.Query)
	if query == "" {
		writeError(w, http.StatusBadRequest, "query is required")
		return
	}
	limit := int64(body.Limit)
	if limit <= 0 || limit > maxChatContexts {
		limit = maxChatContexts
	}
	res, err := h.idx.Search(r.Context(), query, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "search failed")
		return
	}
	contexts := make([]string, 0, len(res.Hits))
	for _, hit := range res.Hits {
		if len(contexts) >= maxChatContexts {
			break
		}
		id, err := uuid.Parse(hit.ID)
		if err != nil {
			continue
		}
		cv, err := h.store.GetByID(r.Context(), id)
		if err != nil {
			continue
		}
		text := ""
		if cv.ExtractedText != nil {
			text = truncateRunes(*cv.ExtractedText, maxChatContextChars)
		}
		contexts = append(contexts, "cv_id="+hit.ID+"\nname="+hit.Name+"\n"+text)
	}
	ans, err := h.pipeline.Chat(r.Context(), query, contexts)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "chat failed")
		return
	}
	writeJSON(w, http.StatusOK, ans)
}

func (h *Handler) GetPipeline(w http.ResponseWriter, r *http.Request) {
	ps, err := h.store.PipelineStats(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "pipeline stats failed")
		return
	}
	writeJSON(w, http.StatusOK, ps)
}

func (h *Handler) GetStats(w http.ResponseWriter, r *http.Request) {
	stats, err := h.store.Stats(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "stats failed")
		return
	}
	jobIDStr := strings.TrimSpace(r.URL.Query().Get("job_id"))
	execID := strings.TrimSpace(r.URL.Query().Get("exec_id"))
	if execID == "" {
		execID = "anonymous"
	}
	out := make([]map[string]any, 0, len(stats))
	for _, st := range stats {
		out = append(out, map[string]any{
			"exec_id":       st.ExecID,
			"total_reviews": st.TotalReviews,
			"likes":         st.Likes,
			"shortlists":    st.Shortlists,
			"stars":         st.Stars,
			"passes":        st.Passes,
			"streak_days":   st.StreakDays,
		})
	}
	resp := map[string]any{"leaderboard": out}
	if jobIDStr != "" {
		if jobID, err := uuid.Parse(jobIDStr); err == nil {
			if reviewed, err := h.store.CountReactionsForJob(r.Context(), jobID, execID); err == nil {
				resp["job_progress"] = map[string]any{
					"job_id":   jobIDStr,
					"exec_id":  execID,
					"reviewed": reviewed,
				}
			}
		}
	}
	writeJSON(w, http.StatusOK, resp)
}
