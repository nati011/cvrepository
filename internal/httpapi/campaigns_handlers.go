package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	pgstore "cvrepo/internal/store/pg"
)

type campaignJSON struct {
	ID             string   `json:"id"`
	Title          string   `json:"title"`
	JDText         string   `json:"jd_text"`
	Status         string   `json:"status"`
	Client         string   `json:"client"`
	HiringManager  string   `json:"hiring_manager"`
	Location       string   `json:"location"`
	Headcount      *int     `json:"headcount,omitempty"`
	StartDate      *string  `json:"start_date,omitempty"`
	EndDate        *string  `json:"end_date,omitempty"`
	Tags           []string `json:"tags"`
	OwnerID        *string  `json:"owner_id,omitempty"`
	CreatedAt      string   `json:"created_at"`
	UpdatedAt      string   `json:"updated_at"`
}

func formatDate(t *time.Time) *string {
	if t == nil {
		return nil
	}
	s := t.UTC().Format("2006-01-02")
	return &s
}

func parseDate(s string) (*time.Time, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil, nil
	}
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		return nil, err
	}
	return &t, nil
}

func toCampaignJSON(j *pgstore.Job) campaignJSON {
	out := campaignJSON{
		ID:            j.ID.String(),
		Title:         j.Title,
		JDText:        j.JDText,
		Status:        string(j.Status),
		Client:        j.Client,
		HiringManager: j.HiringManager,
		Location:      j.Location,
		Headcount:     j.Headcount,
		StartDate:     formatDate(j.StartDate),
		EndDate:       formatDate(j.EndDate),
		Tags:          j.Tags,
		OwnerID:       j.OwnerID,
		CreatedAt:     j.CreatedAt.UTC().Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt:     j.UpdatedAt.UTC().Format("2006-01-02T15:04:05Z07:00"),
	}
	if out.Tags == nil {
		out.Tags = []string{}
	}
	return out
}

type campaignBody struct {
	Title         string   `json:"title"`
	JDText        string   `json:"jd_text"`
	Status        string   `json:"status"`
	Client        string   `json:"client"`
	HiringManager string   `json:"hiring_manager"`
	Location      string   `json:"location"`
	Headcount     *int     `json:"headcount"`
	StartDate     *string  `json:"start_date"`
	EndDate       *string  `json:"end_date"`
	Tags          []string `json:"tags"`
	OwnerID       *string  `json:"owner_id"`
}

func parseCampaignBody(body campaignBody) (*pgstore.Job, error) {
	title := strings.TrimSpace(body.Title)
	jd := strings.TrimSpace(body.JDText)
	if jd == "" {
		return nil, errBadRequest("jd_text is required")
	}
	if title == "" {
		title = "Untitled role"
	}
	status := pgstore.CampaignActive
	if s := strings.TrimSpace(body.Status); s != "" {
		if !pgstore.ValidCampaignStatus(s) {
			return nil, errBadRequest("invalid status")
		}
		status = pgstore.CampaignStatus(s)
	}
	startDate, err := parseDatePtr(body.StartDate)
	if err != nil {
		return nil, errBadRequest("invalid start_date")
	}
	endDate, err := parseDatePtr(body.EndDate)
	if err != nil {
		return nil, errBadRequest("invalid end_date")
	}
	tags := body.Tags
	if tags == nil {
		tags = []string{}
	}
	return &pgstore.Job{
		Kind:          pgstore.JobKindCampaign,
		Title:         title,
		JDText:        jd,
		Status:        status,
		Client:        strings.TrimSpace(body.Client),
		HiringManager: strings.TrimSpace(body.HiringManager),
		Location:      strings.TrimSpace(body.Location),
		Headcount:     body.Headcount,
		StartDate:     startDate,
		EndDate:       endDate,
		Tags:          tags,
		OwnerID:       body.OwnerID,
	}, nil
}

func parseDatePtr(s *string) (*time.Time, error) {
	if s == nil {
		return nil, nil
	}
	return parseDate(*s)
}

type apiError struct {
	msg string
}

func errBadRequest(msg string) error {
	return &apiError{msg: msg}
}

func (e *apiError) Error() string { return e.msg }

func (h *Handler) maybeEnqueueRank(ctx context.Context, jobID uuid.UUID, status pgstore.CampaignStatus, prevStatus pgstore.CampaignStatus) {
	if h.pipeline == nil {
		return
	}
	shouldEnqueue := pgstore.CampaignAllowsAutoRank(status)
	if !shouldEnqueue && prevStatus != status && status == pgstore.CampaignActive {
		shouldEnqueue = true
	}
	if !shouldEnqueue {
		return
	}
	if _, err := h.store.EnqueueRankTasksForJob(ctx, jobID); err != nil {
		log.Printf("enqueue rank tasks for campaign %s: %v", jobID, err)
	}
}

func (h *Handler) PostCampaign(w http.ResponseWriter, r *http.Request) {
	var body campaignBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json body")
		return
	}
	job, err := parseCampaignBody(body)
	if err != nil {
		var ae *apiError
		if errors.As(err, &ae) {
			writeError(w, http.StatusBadRequest, ae.msg)
			return
		}
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.store.CreateJob(r.Context(), job); err != nil {
		writeError(w, http.StatusInternalServerError, "create campaign failed")
		return
	}
	h.maybeEnqueueRank(r.Context(), job.ID, job.Status, "")
	writeJSON(w, http.StatusCreated, toCampaignJSON(job))
}

func (h *Handler) PutCampaign(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	existing, err := h.store.GetJobByKind(r.Context(), id, pgstore.JobKindCampaign)
	if err != nil {
		if errors.Is(err, pgstore.ErrJobNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "get campaign failed")
		return
	}
	var body struct {
		Status string `json:"status"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json body")
		return
	}
	newStatus := strings.TrimSpace(body.Status)
	if newStatus == "" {
		writeError(w, http.StatusBadRequest, "status is required")
		return
	}
	if !pgstore.ValidCampaignStatus(newStatus) {
		writeError(w, http.StatusBadRequest, "invalid status")
		return
	}
	jobStatus := pgstore.CampaignStatus(newStatus)
	prevStatus := existing.Status

	if jobStatus == existing.Status {
		writeError(w, http.StatusConflict, "campaign cannot be modified; deactivate to close")
		return
	}
	if pgstore.CampaignIsDeactivated(existing.Status) {
		writeError(w, http.StatusConflict, "deactivated campaigns cannot be changed")
		return
	}
	if !pgstore.CampaignAllowsDeactivation(existing.Status) {
		writeError(w, http.StatusConflict, "only deactivation is allowed")
		return
	}
	if jobStatus != pgstore.CampaignClosed && jobStatus != pgstore.CampaignArchived {
		writeError(w, http.StatusConflict, "only deactivation (closed or archived) is allowed")
		return
	}
	if err := h.store.UpdateJobStatusOnly(r.Context(), id, jobStatus); err != nil {
		if errors.Is(err, pgstore.ErrJobNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "update campaign failed")
		return
	}
	h.maybeEnqueueRank(r.Context(), id, jobStatus, prevStatus)

	updated, err := h.store.GetJobByKind(r.Context(), id, pgstore.JobKindCampaign)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "get campaign failed")
		return
	}
	writeJSON(w, http.StatusOK, toCampaignJSON(updated))
}

func (h *Handler) DeleteCampaign(w http.ResponseWriter, r *http.Request) {
	writeError(w, http.StatusMethodNotAllowed, "campaigns cannot be deleted; deactivate instead")
}

func (h *Handler) PostCampaignImprove(w http.ResponseWriter, r *http.Request) {
	h.PostJDImprove(w, r)
}

func (h *Handler) ListCampaigns(w http.ResponseWriter, r *http.Request) {
	filter := pgstore.CampaignListFilter{}
	if s := strings.TrimSpace(r.URL.Query().Get("status")); s != "" {
		if !pgstore.ValidCampaignStatus(s) {
			writeError(w, http.StatusBadRequest, "invalid status filter")
			return
		}
		st := pgstore.CampaignStatus(s)
		filter.Status = &st
	}
	filter.Client = strings.TrimSpace(r.URL.Query().Get("client"))
	filter.Tag = strings.TrimSpace(r.URL.Query().Get("tag"))

	jobs, err := h.store.ListCampaigns(r.Context(), filter)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list campaigns failed")
		return
	}
	out := make([]campaignJSON, 0, len(jobs))
	for i := range jobs {
		out = append(out, toCampaignJSON(&jobs[i]))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

func (h *Handler) GetCampaign(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	job, err := h.store.GetJobByKind(r.Context(), id, pgstore.JobKindCampaign)
	if err != nil {
		if errors.Is(err, pgstore.ErrJobNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "get campaign failed")
		return
	}
	writeJSON(w, http.StatusOK, toCampaignJSON(job))
}

func (h *Handler) PostCampaignRank(w http.ResponseWriter, r *http.Request) {
	if h.pipeline == nil {
		writeError(w, http.StatusServiceUnavailable, "AI pipeline not configured")
		return
	}
	jobID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	job, err := h.store.GetJobByKind(r.Context(), jobID, pgstore.JobKindCampaign)
	if err != nil {
		if errors.Is(err, pgstore.ErrJobNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "get campaign failed")
		return
	}
	if !pgstore.CampaignAllowsManualRank(job.Status) {
		writeError(w, http.StatusConflict, "ranking not allowed for this campaign status")
		return
	}
	queued, err := h.store.EnqueueRankTasksForJob(r.Context(), jobID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "enqueue rank tasks failed")
		return
	}
	writeJSON(w, http.StatusAccepted, map[string]any{
		"campaign_id": jobID.String(),
		"job_id":      jobID.String(),
		"queued":      queued,
	})
}

func (h *Handler) GetCampaignRankStatus(w http.ResponseWriter, r *http.Request) {
	jobID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	if _, err := h.store.GetJobByKind(r.Context(), jobID, pgstore.JobKindCampaign); err != nil {
		if errors.Is(err, pgstore.ErrJobNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "get campaign failed")
		return
	}
	st, err := h.store.RankStatusForJob(r.Context(), jobID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "rank status failed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"campaign_id": jobID.String(),
		"job_id":      jobID.String(),
		"pending":     st.Pending,
		"processing":  st.Processing,
		"done":        st.Done,
		"failed":      st.Failed,
	})
}

func (h *Handler) GetCampaignFeed(w http.ResponseWriter, r *http.Request) {
	h.writeRoleFeed(w, r, pgstore.JobKindCampaign)
}

func (h *Handler) GetCampaignStats(w http.ResponseWriter, r *http.Request) {
	jobID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	stats, err := h.store.CampaignStatsForJob(r.Context(), jobID)
	if err != nil {
		if errors.Is(err, pgstore.ErrJobNotFound) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "campaign stats failed")
		return
	}
	writeJSON(w, http.StatusOK, stats)
}
