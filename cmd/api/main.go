package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"cvrepo/internal/config"
	"cvrepo/internal/httpapi"
	"cvrepo/internal/migrate"
	meiliidx "cvrepo/internal/search/meili"
	fsstorage "cvrepo/internal/storage/fs"
	pgstore "cvrepo/internal/store/pg"
)

func main() {
	def := "config.yaml"
	if v := os.Getenv("CONFIG_PATH"); v != "" {
		def = v
	}
	configPath := flag.String("config", def, "path to YAML config file")
	flag.Parse()
	cfg, err := config.LoadFile(*configPath)
	if err != nil {
		log.Fatalf("config: %v", err)
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("db: %v", err)
	}
	defer pool.Close()
	if err := migrate.Up(ctx, pool); err != nil {
		log.Fatalf("migrate: %v", err)
	}

	fs, err := fsstorage.New(cfg.CVStorageRoot)
	if err != nil {
		log.Fatalf("fs storage: %v", err)
	}
	idx, err := meiliidx.New(cfg.MeiliHost, cfg.MeiliAPIKey, cfg.MeiliIndex)
	if err != nil {
		log.Fatalf("meilisearch: %v", err)
	}

	store := pgstore.NewStore(pool)
	h := httpapi.NewHandler(store, fs, idx, httpapi.BatchLimits{
		MaxRequestBytes: cfg.BatchMaxRequestBytes,
		MaxFileBytes:    cfg.BatchMaxFileBytes,
		MaxFiles:        cfg.BatchMaxFiles,
	})
	srv := &http.Server{
		Addr:         cfg.HTTPAddr,
		Handler:      httpapi.NewRouter(h),
		ReadTimeout:  60 * time.Second,
		WriteTimeout: 60 * time.Second,
	}

	go func() {
		log.Printf("api listening on %s", cfg.HTTPAddr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop
	shctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(shctx)
}
