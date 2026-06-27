package httpapi

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func NewRouter(h *Handler) http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	r.Route("/v1", func(r chi.Router) {
		r.Post("/cvs", h.PostCV)
		r.Post("/cvs/batch", h.PostCVBatch)
		r.Get("/cvs", h.ListCVs)
		r.Get("/cvs/{id}/file", h.GetCVFile)
		r.Get("/cvs/{id}", h.GetCV)
		r.Delete("/cvs/{id}", h.DeleteCV)
		r.Get("/search", h.Search)
		r.Post("/jobs", h.PostJob)
		r.Post("/jobs/improve", h.PostJDImprove)
		r.Get("/jobs", h.ListJobs)
		r.Get("/jobs/{id}", h.GetJob)
		r.Put("/jobs/{id}", h.PutJob)
		r.Delete("/jobs/{id}", h.DeleteJob)
		r.Post("/jobs/{id}/rank", h.PostJobRank)
		r.Get("/jobs/{id}/rank", h.GetJobRankStatus)
		r.Get("/jobs/{id}/feed", h.GetJobFeed)
		r.Post("/campaigns", h.PostCampaign)
		r.Post("/campaigns/improve", h.PostCampaignImprove)
		r.Get("/campaigns", h.ListCampaigns)
		r.Get("/campaigns/{id}", h.GetCampaign)
		r.Put("/campaigns/{id}", h.PutCampaign)
		r.Delete("/campaigns/{id}", h.DeleteCampaign)
		r.Post("/campaigns/{id}/rank", h.PostCampaignRank)
		r.Get("/campaigns/{id}/rank", h.GetCampaignRankStatus)
		r.Get("/campaigns/{id}/feed", h.GetCampaignFeed)
		r.Get("/campaigns/{id}/stats", h.GetCampaignStats)
		r.Post("/cvs/{id}/reactions", h.PostReaction)
		r.Get("/reactions", h.ListReactions)
		r.Delete("/reactions/{id}", h.DeleteReaction)
		r.Post("/cvs/{id}/comments", h.PostComment)
		r.Post("/chat", h.PostChat)
		r.Get("/stats", h.GetStats)
		r.Get("/pipeline", h.GetPipeline)
	})
	return r
}
