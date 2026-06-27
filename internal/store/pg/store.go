package pgstore

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("cv not found")

type Store struct {
	pool *pgxpool.Pool
}

func NewStore(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

func (s *Store) Create(ctx context.Context, cv *CV) error {
	const q = `
		INSERT INTO cvs (id, title, original_filename, content_type, storage_key, sha256, size_bytes, owner_id, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`
	now := time.Now().UTC()
	if cv.ID == uuid.Nil {
		cv.ID = uuid.New()
	}
	cv.CreatedAt = now
	cv.UpdatedAt = now
	_, err := s.pool.Exec(ctx, q,
		cv.ID, cv.Title, cv.OriginalFilename, cv.ContentType, cv.StorageKey, cv.SHA256, cv.SizeBytes, cv.OwnerID, string(cv.Status), cv.CreatedAt, cv.UpdatedAt,
	)
	return err
}

func (s *Store) GetByID(ctx context.Context, id uuid.UUID) (*CV, error) {
	const q = `SELECT ` + cvSelectCols + ` FROM cvs WHERE id = $1`
	row := s.pool.QueryRow(ctx, q, id)
	cv, err := scanCV(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return cv, nil
}

func (s *Store) List(ctx context.Context, limit, offset int) ([]CV, int64, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}
	var total int64
	if err := s.pool.QueryRow(ctx, `SELECT COUNT(*) FROM cvs`).Scan(&total); err != nil {
		return nil, 0, err
	}
	const q = `SELECT ` + cvSelectCols + ` FROM cvs ORDER BY created_at DESC LIMIT $1 OFFSET $2`
	rows, err := s.pool.Query(ctx, q, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	var list []CV
	for rows.Next() {
		cv, err := scanCV(rows)
		if err != nil {
			return nil, 0, err
		}
		list = append(list, *cv)
	}
	return list, total, rows.Err()
}

func (s *Store) DeleteRow(ctx context.Context, id uuid.UUID) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM cvs WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) ClaimPending(ctx context.Context) (*CV, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)
	const q = `
		SELECT ` + cvSelectCols + `
		FROM cvs
		WHERE status = 'pending'
		ORDER BY created_at ASC
		FOR UPDATE SKIP LOCKED
		LIMIT 1
	`
	row := tx.QueryRow(ctx, q)
	cv, err := scanCV(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	const up = `UPDATE cvs SET status = 'processing', updated_at = $2 WHERE id = $1 AND status = 'pending'`
	tag, err := tx.Exec(ctx, up, cv.ID, time.Now().UTC())
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, nil
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	cv.Status = StatusProcessing
	cv.UpdatedAt = time.Now().UTC()
	return cv, nil
}

func (s *Store) MarkReady(ctx context.Context, id uuid.UUID, extractedText string) error {
	const q = `
		UPDATE cvs SET status = 'ready', extracted_text = $2, parse_error = NULL, updated_at = $3 WHERE id = $1
	`
	_, err := s.pool.Exec(ctx, q, id, extractedText, time.Now().UTC())
	return err
}

func (s *Store) MarkFailed(ctx context.Context, id uuid.UUID, parseErr string) error {
	const q = `
		UPDATE cvs SET status = 'failed', parse_error = $2, updated_at = $3 WHERE id = $1
	`
	_, err := s.pool.Exec(ctx, q, id, parseErr, time.Now().UTC())
	return err
}

// ResetStaleProcessing moves CVs left in processing back to pending after a worker crash.
func (s *Store) ResetStaleProcessing(ctx context.Context) (int64, error) {
	const q = `UPDATE cvs SET status = 'pending', updated_at = $1 WHERE status = 'processing'`
	tag, err := s.pool.Exec(ctx, q, time.Now().UTC())
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// ResetStaleProfileProcessing moves profile extraction left in processing back to pending.
func (s *Store) ResetStaleProfileProcessing(ctx context.Context) (int64, error) {
	const q = `UPDATE cvs SET profile_status = 'pending', updated_at = $1 WHERE profile_status = 'processing'`
	tag, err := s.pool.Exec(ctx, q, time.Now().UTC())
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

func scanCV(row pgx.Row) (*CV, error) {
	var cv CV
	var ownerID *string
	var parseErr *string
	var extracted *string
	var status string
	var profileStatus string
	err := row.Scan(
		&cv.ID, &cv.Title, &cv.OriginalFilename, &cv.ContentType, &cv.StorageKey, &cv.SHA256, &cv.SizeBytes,
		&ownerID, &status, &parseErr, &extracted, &cv.Profile, &profileStatus, &cv.CreatedAt, &cv.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	cv.OwnerID = ownerID
	cv.ParseError = parseErr
	cv.ExtractedText = extracted
	cv.Status = CVStatus(status)
	cv.ProfileStatus = ProfileStatus(profileStatus)
	if cv.ProfileStatus == "" {
		cv.ProfileStatus = ProfilePending
	}
	if cv.Status != StatusPending && cv.Status != StatusProcessing && cv.Status != StatusReady && cv.Status != StatusFailed {
		return nil, fmt.Errorf("invalid status %q", status)
	}
	return &cv, nil
}
