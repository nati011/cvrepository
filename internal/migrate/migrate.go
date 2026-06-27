package migrate

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

var statements = []string{
	`CREATE EXTENSION IF NOT EXISTS pgcrypto`,
	`
CREATE TABLE IF NOT EXISTS cvs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL DEFAULT '',
    original_filename TEXT NOT NULL,
    content_type TEXT NOT NULL DEFAULT 'application/pdf',
    storage_key TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    size_bytes BIGINT NOT NULL,
    owner_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'ready', 'failed')),
    parse_error TEXT,
    extracted_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
)`,
	`CREATE UNIQUE INDEX IF NOT EXISTS cvs_storage_key_idx ON cvs (storage_key)`,
	`CREATE INDEX IF NOT EXISTS cvs_status_created_idx ON cvs (status, created_at DESC)`,
	`CREATE INDEX IF NOT EXISTS cvs_created_at_idx ON cvs (created_at DESC)`,
	`ALTER TABLE cvs ADD COLUMN IF NOT EXISTS profile JSONB`,
	`ALTER TABLE cvs ADD COLUMN IF NOT EXISTS profile_status TEXT NOT NULL DEFAULT 'pending'`,
	`ALTER TABLE cvs DROP CONSTRAINT IF EXISTS cvs_profile_status_check`,
	`ALTER TABLE cvs ADD CONSTRAINT cvs_profile_status_check CHECK (profile_status IN ('pending', 'processing', 'ready', 'failed'))`,
	`CREATE INDEX IF NOT EXISTS cvs_profile_status_idx ON cvs (profile_status, created_at ASC)`,
	`
CREATE TABLE IF NOT EXISTS jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL DEFAULT '',
    jd_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
)`,
	`CREATE INDEX IF NOT EXISTS jobs_created_at_idx ON jobs (created_at DESC)`,
	`
CREATE TABLE IF NOT EXISTS scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cv_id UUID NOT NULL REFERENCES cvs(id) ON DELETE CASCADE,
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    score INT NOT NULL,
    subscores JSONB NOT NULL DEFAULT '{}',
    evidence JSONB NOT NULL DEFAULT '[]',
    one_pager JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (cv_id, job_id)
)`,
	`CREATE INDEX IF NOT EXISTS scores_job_score_idx ON scores (job_id, score DESC)`,
	`
CREATE TABLE IF NOT EXISTS reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cv_id UUID NOT NULL REFERENCES cvs(id) ON DELETE CASCADE,
    job_id UUID REFERENCES jobs(id) ON DELETE SET NULL,
    exec_id TEXT,
    action TEXT NOT NULL CHECK (action IN ('shortlist', 'pass', 'star')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
)`,
	`CREATE INDEX IF NOT EXISTS reactions_cv_idx ON reactions (cv_id, created_at DESC)`,
	`CREATE INDEX IF NOT EXISTS reactions_exec_idx ON reactions (exec_id, created_at DESC)`,
	`
CREATE TABLE IF NOT EXISTS comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cv_id UUID NOT NULL REFERENCES cvs(id) ON DELETE CASCADE,
    author TEXT NOT NULL DEFAULT '',
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
)`,
	`CREATE INDEX IF NOT EXISTS comments_cv_idx ON comments (cv_id, created_at DESC)`,
	`
CREATE TABLE IF NOT EXISTS rank_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cv_id UUID NOT NULL REFERENCES cvs(id) ON DELETE CASCADE,
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    state TEXT NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'processing', 'done', 'failed')),
    error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (cv_id, job_id)
)`,
	`CREATE INDEX IF NOT EXISTS rank_tasks_state_idx ON rank_tasks (state, created_at ASC)`,
	`CREATE INDEX IF NOT EXISTS rank_tasks_job_state_idx ON rank_tasks (job_id, state)`,
	// Campaign metadata (jobs table enriched)
	`ALTER TABLE jobs ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'`,
	`ALTER TABLE jobs DROP CONSTRAINT IF EXISTS jobs_status_check`,
	`ALTER TABLE jobs ADD CONSTRAINT jobs_status_check CHECK (status IN ('draft', 'active', 'paused', 'closed', 'archived'))`,
	`ALTER TABLE jobs ADD COLUMN IF NOT EXISTS client TEXT NOT NULL DEFAULT ''`,
	`ALTER TABLE jobs ADD COLUMN IF NOT EXISTS hiring_manager TEXT NOT NULL DEFAULT ''`,
	`ALTER TABLE jobs ADD COLUMN IF NOT EXISTS location TEXT NOT NULL DEFAULT ''`,
	`ALTER TABLE jobs ADD COLUMN IF NOT EXISTS headcount INT`,
	`ALTER TABLE jobs ADD COLUMN IF NOT EXISTS start_date DATE`,
	`ALTER TABLE jobs ADD COLUMN IF NOT EXISTS end_date DATE`,
	`ALTER TABLE jobs ADD COLUMN IF NOT EXISTS tags TEXT[] NOT NULL DEFAULT '{}'`,
	`ALTER TABLE jobs ADD COLUMN IF NOT EXISTS owner_id TEXT`,
	`ALTER TABLE jobs ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`,
	`UPDATE jobs SET updated_at = created_at WHERE updated_at IS NULL OR updated_at < created_at`,
	`CREATE INDEX IF NOT EXISTS jobs_status_created_idx ON jobs (status, created_at DESC)`,
	// Distinguish reusable job definitions from operational hiring campaigns.
	`ALTER TABLE jobs ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'campaign'`,
	`ALTER TABLE jobs DROP CONSTRAINT IF EXISTS jobs_kind_check`,
	`ALTER TABLE jobs ADD CONSTRAINT jobs_kind_check CHECK (kind IN ('job', 'campaign'))`,
	`CREATE INDEX IF NOT EXISTS jobs_kind_created_idx ON jobs (kind, created_at DESC)`,
	// Feed engagement: allow global "like" reactions (distinct from campaign shortlist).
	`ALTER TABLE reactions DROP CONSTRAINT IF EXISTS reactions_action_check`,
	`ALTER TABLE reactions ADD CONSTRAINT reactions_action_check CHECK (action IN ('shortlist', 'pass', 'star', 'like'))`,
}

func Up(ctx context.Context, pool *pgxpool.Pool) error {
	for i, s := range statements {
		if _, err := pool.Exec(ctx, s); err != nil {
			return fmt.Errorf("migration step %d: %w", i+1, err)
		}
	}
	return nil
}
