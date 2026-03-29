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
	})
	return r
}
