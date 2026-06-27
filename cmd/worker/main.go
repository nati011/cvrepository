package main

import (
	"context"
	"encoding/json"
	"flag"
	"io"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"cvrepo/internal/config"
	"cvrepo/internal/groq"
	"cvrepo/internal/migrate"
	"cvrepo/internal/pdftotext"
	"cvrepo/internal/pipeline"
	meiliidx "cvrepo/internal/search/meili"
	fsstorage "cvrepo/internal/storage/fs"
	pgstore "cvrepo/internal/store/pg"
	"cvrepo/internal/tika"
)

type textExtractor interface {
	ExtractText(ctx context.Context, contentType string, r io.Reader) (string, error)
}

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
	var extractor textExtractor
	if os.Getenv("CVREPO_USE_PDFTOTEXT") == "1" {
		log.Println("using pdftotext for PDF extraction (CVREPO_USE_PDFTOTEXT=1)")
		extractor = pdftotext.New()
	} else {
		extractor = tika.New(cfg.TikaURL)
	}
	groqClient := groq.New(cfg.GroqAPIKey, cfg.GroqBaseURL, cfg.GroqModel)
	pipe := pipeline.New(groqClient)
	store := pgstore.NewStore(pool)

	if n, err := store.ResetStaleProcessing(ctx); err != nil {
		log.Printf("reset stale cv processing: %v", err)
	} else if n > 0 {
		log.Printf("reset %d cv(s) from processing to pending", n)
	}
	if n, err := store.ResetStaleProfileProcessing(ctx); err != nil {
		log.Printf("reset stale profile processing: %v", err)
	} else if n > 0 {
		log.Printf("reset %d cv profile(s) from processing to pending", n)
	}
	if n, err := store.ResetStaleRankTasks(ctx); err != nil {
		log.Printf("reset stale rank tasks: %v", err)
	} else if n > 0 {
		log.Printf("reset %d rank task(s) from processing to pending", n)
	}

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
		runOnce(ctx, store, fs, extractor, idx, pipe)
		runProfileTask(ctx, store, idx, pipe)
		runRankTask(ctx, store, pipe)
		select {
		case <-ctx.Done():
			return
		case <-time.After(cfg.WorkerPollInterval):
		}
	}
}

func runOnce(ctx context.Context, store *pgstore.Store, fs *fsstorage.Store, extractor textExtractor, idx *meiliidx.Index, pipe *pipeline.Service) {
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
	text, err := extractor.ExtractText(ctx, cv.ContentType, f)
	_ = f.Close()
	if err != nil {
		if err := store.MarkFailed(ctx, cv.ID, "extract: "+err.Error()); err != nil {
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

func runProfileTask(ctx context.Context, store *pgstore.Store, idx *meiliidx.Index, pipe *pipeline.Service) {
	if pipe == nil {
		return
	}
	profileCV, err := store.ClaimPendingProfile(ctx)
	if err != nil {
		log.Printf("claim pending profile: %v", err)
		return
	}
	if profileCV == nil {
		return
	}
	log.Printf("profiling cv %s", profileCV.ID)
	if profileCV.ExtractedText == nil || *profileCV.ExtractedText == "" {
		if err := store.MarkProfileFailed(ctx, profileCV.ID, "empty extracted text"); err != nil {
			log.Printf("mark profile failed: %v", err)
		}
		return
	}
	profile, err := pipe.ExtractProfile(ctx, *profileCV.ExtractedText)
	if err != nil {
		if err := store.MarkProfileFailed(ctx, profileCV.ID, "groq profile extraction: "+err.Error()); err != nil {
			log.Printf("mark profile failed: %v", err)
		}
		return
	}
	profileJSON, err := json.Marshal(profile)
	if err != nil {
		if err := store.MarkProfileFailed(ctx, profileCV.ID, "marshal profile: "+err.Error()); err != nil {
			log.Printf("mark profile failed: %v", err)
		}
		return
	}
	if err := store.SaveProfile(ctx, profileCV.ID, profileJSON); err != nil {
		log.Printf("save profile: %v", err)
		return
	}
	freshProfile, err := store.GetByID(ctx, profileCV.ID)
	if err != nil {
		log.Printf("reload profiled cv: %v", err)
		return
	}
	if err := idx.IndexCV(ctx, freshProfile); err != nil {
		log.Printf("meilisearch profile index: %v", err)
	}

	// Auto-rank: once a CV is profiled, queue it against every existing job.
	if n, err := store.EnqueueRankTasksForCV(ctx, profileCV.ID); err != nil {
		log.Printf("auto-enqueue rank tasks for cv %s: %v", profileCV.ID, err)
	} else if n > 0 {
		log.Printf("auto-queued cv %s for ranking against %d job(s)", profileCV.ID, n)
	}
}

// runRankTask claims and processes a single pending rank task: it scores the CV
// against the job's JD and persists the result. Errors are recorded on the task
// so re-ranking can be retried via the queue.
func runRankTask(ctx context.Context, store *pgstore.Store, pipe *pipeline.Service) {
	if pipe == nil {
		return
	}
	task, err := store.ClaimPendingRankTask(ctx)
	if err != nil {
		log.Printf("claim rank task: %v", err)
		return
	}
	if task == nil {
		return
	}
	cv, err := store.GetByID(ctx, task.CVID)
	if err != nil {
		_ = store.MarkRankTaskFailed(ctx, task.ID, "load cv: "+err.Error())
		return
	}
	job, err := store.GetJob(ctx, task.JobID)
	if err != nil {
		_ = store.MarkRankTaskFailed(ctx, task.ID, "load job: "+err.Error())
		return
	}
	cvText := ""
	if cv.ExtractedText != nil {
		cvText = *cv.ExtractedText
	}
	res, err := pipe.RankCV(ctx, job.JDText, cv.Profile, cvText)
	if err != nil {
		_ = store.MarkRankTaskFailed(ctx, task.ID, "rank: "+err.Error())
		return
	}
	if err := store.UpsertScore(ctx, &pgstore.Score{
		CVID:      task.CVID,
		JobID:     task.JobID,
		Score:     res.Score,
		Subscores: res.Subscores,
		Evidence:  res.Evidence,
		OnePager:  res.OnePager,
	}); err != nil {
		_ = store.MarkRankTaskFailed(ctx, task.ID, "save score: "+err.Error())
		return
	}
	if err := store.MarkRankTaskDone(ctx, task.ID); err != nil {
		log.Printf("mark rank task done: %v", err)
	}
}
