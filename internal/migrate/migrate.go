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
}

func Up(ctx context.Context, pool *pgxpool.Pool) error {
	for i, s := range statements {
		if _, err := pool.Exec(ctx, s); err != nil {
			return fmt.Errorf("migration step %d: %w", i+1, err)
		}
	}
	return nil
}
