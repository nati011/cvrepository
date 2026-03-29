package main

import (
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"cvrepo/internal/config"
	"cvrepo/internal/migrate"
	meiliidx "cvrepo/internal/search/meili"
	fsstorage "cvrepo/internal/storage/fs"
	pgstore "cvrepo/internal/store/pg"
	"cvrepo/internal/tika"
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
	tikaClient := tika.New(cfg.TikaURL)
	store := pgstore.NewStore(pool)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() {
		sig := make(chan os.Signal, 1)
		signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
		<-sig
		cancel()
	}()

	log.Printf("worker polling every %s", cfg.WorkerPollInterval)
	for {
		select {
		case <-ctx.Done():
			log.Println("worker stopping")
			return
		default:
		}
		runOnce(ctx, store, fs, tikaClient, idx)
		select {
		case <-ctx.Done():
			return
		case <-time.After(cfg.WorkerPollInterval):
		}
	}
}

func runOnce(ctx context.Context, store *pgstore.Store, fs *fsstorage.Store, tikaClient *tika.Client, idx *meiliidx.Index) {
	cv, err := store.ClaimPending(ctx)
	if err != nil {
		log.Printf("claim: %v", err)
		return
	}
	if cv == nil {
		return
	}
	log.Printf("processing cv %s", cv.ID)

	f, err := fs.Open(cv.StorageKey)
	if err != nil {
		msg := err.Error()
		if err := store.MarkFailed(ctx, cv.ID, "open file: "+msg); err != nil {
			log.Printf("mark failed: %v", err)
		}
		return
	}
	text, err := tikaClient.ExtractText(ctx, cv.ContentType, f)
	_ = f.Close()
	if err != nil {
		if err := store.MarkFailed(ctx, cv.ID, "tika: "+err.Error()); err != nil {
			log.Printf("mark failed: %v", err)
		}
		return
	}
	if err := store.MarkReady(ctx, cv.ID, text); err != nil {
		log.Printf("mark ready: %v", err)
		return
	}
	fresh, err := store.GetByID(ctx, cv.ID)
	if err != nil {
		log.Printf("reload cv: %v", err)
		return
	}
	if err := idx.IndexCV(ctx, fresh); err != nil {
		log.Printf("meilisearch index: %v", err)
	}
}
