package pgstore

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var ErrJobNotFound = errors.New("job not found")

const cvSelectCols = `id, title, original_filename, content_type, storage_key, sha256, size_bytes, owner_id, status, parse_error, extracted_text, profile, profile_status, created_at, updated_at`

const jobSelectCols = `id, kind, title, jd_text, status, client, hiring_manager, location, headcount, start_date, end_date, tags, owner_id, created_at, updated_at`

func scanJob(row pgx.Row) (*Job, error) {
	var j Job
	var kind string
	var status string
	var headcount *int
	var startDate, endDate *time.Time
	var tags []string
	var ownerID *string
	if err := row.Scan(
		&j.ID, &kind, &j.Title, &j.JDText, &status,
		&j.Client, &j.HiringManager, &j.Location,
		&headcount, &startDate, &endDate, &tags, &ownerID,
		&j.CreatedAt, &j.UpdatedAt,
	); err != nil {
		return nil, err
	}
	j.Kind = JobKind(kind)
	j.Status = CampaignStatus(status)
	j.Headcount = headcount
	j.StartDate = startDate
	j.EndDate = endDate
	j.Tags = tags
	if j.Tags == nil {
		j.Tags = []string{}
	}
	j.OwnerID = ownerID
	return &j, nil
}

func (s *Store) ListReadyWithProfile(ctx context.Context) ([]CV, error) {
	const q = `SELECT ` + cvSelectCols + ` FROM cvs WHERE status = 'ready' AND profile_status = 'ready' ORDER BY created_at ASC`
	rows, err := s.pool.Query(ctx, q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []CV
	for rows.Next() {
		cv, err := scanCV(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, *cv)
	}
	return list, rows.Err()
}

func (s *Store) ClaimPendingProfile(ctx context.Context) (*CV, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)
	const q = `
		SELECT ` + cvSelectCols + `
		FROM cvs
		WHERE status = 'ready' AND profile_status = 'pending'
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
	const up = `UPDATE cvs SET profile_status = 'processing', updated_at = $2 WHERE id = $1 AND profile_status = 'pending'`
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
	cv.ProfileStatus = ProfileProcessing
	cv.UpdatedAt = time.Now().UTC()
	return cv, nil
}

func (s *Store) SaveProfile(ctx context.Context, id uuid.UUID, profile json.RawMessage) error {
	const q = `UPDATE cvs SET profile = $2, profile_status = 'ready', updated_at = $3 WHERE id = $1`
	_, err := s.pool.Exec(ctx, q, id, profile, time.Now().UTC())
	return err
}

func (s *Store) MarkProfileFailed(ctx context.Context, id uuid.UUID, errMsg string) error {
	const q = `UPDATE cvs SET profile_status = 'failed', parse_error = $2, updated_at = $3 WHERE id = $1`
	_, err := s.pool.Exec(ctx, q, id, errMsg, time.Now().UTC())
	return err
}

func (s *Store) CreateJob(ctx context.Context, job *Job) error {
	now := time.Now().UTC()
	if job.ID == uuid.Nil {
		job.ID = uuid.New()
	}
	if job.Kind == "" {
		job.Kind = JobKindCampaign
	}
  if job.Status == "" {
		job.Status = CampaignActive
	}
	if job.Tags == nil {
		job.Tags = []string{}
	}
	job.CreatedAt = now
	job.UpdatedAt = now
	const q = `
		INSERT INTO jobs (
			id, kind, title, jd_text, status, client, hiring_manager, location,
			headcount, start_date, end_date, tags, owner_id, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
	`
	_, err := s.pool.Exec(ctx, q,
		job.ID, string(job.Kind), job.Title, job.JDText, string(job.Status),
		job.Client, job.HiringManager, job.Location,
		job.Headcount, job.StartDate, job.EndDate, job.Tags, job.OwnerID,
		job.CreatedAt, job.UpdatedAt,
	)
	return err
}

func (s *Store) UpdateJobContent(ctx context.Context, id uuid.UUID, title, jdText string) error {
	now := time.Now().UTC()
	const q = `UPDATE jobs SET title = $2, jd_text = $3, updated_at = $4 WHERE id = $1 AND kind = 'job'`
	tag, err := s.pool.Exec(ctx, q, id, title, jdText, now)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrJobNotFound
	}
	return nil
}

func (s *Store) GetJobByKind(ctx context.Context, id uuid.UUID, kind JobKind) (*Job, error) {
	job, err := s.GetJob(ctx, id)
	if err != nil {
		return nil, err
	}
	if job.Kind != kind {
		return nil, ErrJobNotFound
	}
	return job, nil
}

func (s *Store) UpdateJobStatusOnly(ctx context.Context, id uuid.UUID, status CampaignStatus) error {
	now := time.Now().UTC()
	const q = `UPDATE jobs SET status = $2, updated_at = $3 WHERE id = $1`
	tag, err := s.pool.Exec(ctx, q, id, string(status), now)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrJobNotFound
	}
	return nil
}

func (s *Store) DeleteJob(ctx context.Context, id uuid.UUID) error {
	const q = `DELETE FROM jobs WHERE id = $1 AND kind = 'job'`
	tag, err := s.pool.Exec(ctx, q, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrJobNotFound
	}
	return nil
}

func (s *Store) ListJobs(ctx context.Context) ([]Job, error) {
	const q = `SELECT ` + jobSelectCols + ` FROM jobs WHERE kind = 'job' ORDER BY created_at DESC`
	rows, err := s.pool.Query(ctx, q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Job
	for rows.Next() {
		j, err := scanJob(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, *j)
	}
	return list, rows.Err()
}

func (s *Store) ListCampaigns(ctx context.Context, filter CampaignListFilter) ([]Job, error) {
	q := `SELECT ` + jobSelectCols + ` FROM jobs WHERE kind = 'campaign'`
	args := []any{}
	argN := 1
	if filter.Status != nil {
		q += fmt.Sprintf(` AND status = $%d`, argN)
		args = append(args, string(*filter.Status))
		argN++
	} else {
		q += ` AND status NOT IN ('closed', 'archived')`
	}
	if filter.Client != "" {
		q += fmt.Sprintf(` AND client ILIKE $%d`, argN)
		args = append(args, "%"+filter.Client+"%")
		argN++
	}
	if filter.Tag != "" {
		q += fmt.Sprintf(` AND $%d = ANY(tags)`, argN)
		args = append(args, filter.Tag)
		argN++
	}
	q += ` ORDER BY created_at DESC`
	rows, err := s.pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Job
	for rows.Next() {
		j, err := scanJob(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, *j)
	}
	return list, rows.Err()
}

func (s *Store) GetJob(ctx context.Context, id uuid.UUID) (*Job, error) {
	const q = `SELECT ` + jobSelectCols + ` FROM jobs WHERE id = $1`
	j, err := scanJob(s.pool.QueryRow(ctx, q, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrJobNotFound
		}
		return nil, err
	}
	return j, nil
}

func (s *Store) CampaignStatsForJob(ctx context.Context, jobID uuid.UUID) (*CampaignStats, error) {
	if _, err := s.GetJob(ctx, jobID); err != nil {
		return nil, err
	}
	var stats CampaignStats
	if err := s.pool.QueryRow(ctx, `SELECT COUNT(*), AVG(score)::float8, MAX(score) FROM scores WHERE job_id = $1`, jobID).
		Scan(&stats.RankedCount, &stats.AvgScore, &stats.TopScore); err != nil {
		return nil, err
	}
	rankSt, err := s.RankStatusForJob(ctx, jobID)
	if err != nil {
		return nil, err
	}
	stats.RankStatus = rankSt
	const reactQ = `
		SELECT
			COUNT(*) FILTER (WHERE action = 'shortlist') AS shortlist,
			COUNT(*) FILTER (WHERE action = 'star') AS star,
			COUNT(*) FILTER (WHERE action = 'pass') AS pass
		FROM (
			SELECT DISTINCT ON (cv_id) action
			FROM reactions
			WHERE job_id = $1
			ORDER BY cv_id, created_at DESC
		) latest
	`
	if err := s.pool.QueryRow(ctx, reactQ, jobID).
		Scan(&stats.Reactions.Shortlist, &stats.Reactions.Star, &stats.Reactions.Pass); err != nil {
		return nil, err
	}
	stats.ReviewedCount = stats.Reactions.Shortlist + stats.Reactions.Star + stats.Reactions.Pass
	return &stats, nil
}

// EnqueueRankTasksForJob creates (or resets) one pending rank task per ready, profiled CV.
// It is idempotent: existing tasks for the same (cv_id, job_id) are reset to pending.
func (s *Store) EnqueueRankTasksForJob(ctx context.Context, jobID uuid.UUID) (int64, error) {
	const q = `
		INSERT INTO rank_tasks (cv_id, job_id, state, error, created_at, updated_at)
		SELECT c.id, $1, 'pending', NULL, now(), now()
		FROM cvs c
		WHERE c.status = 'ready' AND c.profile_status = 'ready'
		ON CONFLICT (cv_id, job_id) DO UPDATE SET
			state = 'pending',
			error = NULL,
			updated_at = now()
	`
	tag, err := s.pool.Exec(ctx, q, jobID)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// EnqueueRankTasksForCV creates (or resets) one pending rank task for this CV
// against every existing job. Used to auto-rank a CV once its profile is ready.
// It is idempotent: existing tasks for the same (cv_id, job_id) are reset to pending.
func (s *Store) EnqueueRankTasksForCV(ctx context.Context, cvID uuid.UUID) (int64, error) {
	const q = `
		INSERT INTO rank_tasks (cv_id, job_id, state, error, created_at, updated_at)
		SELECT $1, j.id, 'pending', NULL, now(), now()
		FROM jobs j
		ON CONFLICT (cv_id, job_id) DO UPDATE SET
			state = 'pending',
			error = NULL,
			updated_at = now()
	`
	tag, err := s.pool.Exec(ctx, q, cvID)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// ClaimPendingRankTask atomically claims one pending rank task.
func (s *Store) ClaimPendingRankTask(ctx context.Context) (*RankTask, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)
	const q = `
		SELECT id, cv_id, job_id, state, error, created_at, updated_at
		FROM rank_tasks
		WHERE state = 'pending'
		ORDER BY created_at ASC
		FOR UPDATE SKIP LOCKED
		LIMIT 1
	`
	var t RankTask
	if err := tx.QueryRow(ctx, q).Scan(&t.ID, &t.CVID, &t.JobID, &t.State, &t.Error, &t.CreatedAt, &t.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	const up = `UPDATE rank_tasks SET state = 'processing', updated_at = $2 WHERE id = $1 AND state = 'pending'`
	tag, err := tx.Exec(ctx, up, t.ID, time.Now().UTC())
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, nil
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	t.State = "processing"
	return &t, nil
}

func (s *Store) MarkRankTaskDone(ctx context.Context, id uuid.UUID) error {
	const q = `UPDATE rank_tasks SET state = 'done', error = NULL, updated_at = $2 WHERE id = $1`
	_, err := s.pool.Exec(ctx, q, id, time.Now().UTC())
	return err
}

func (s *Store) MarkRankTaskFailed(ctx context.Context, id uuid.UUID, errMsg string) error {
	const q = `UPDATE rank_tasks SET state = 'failed', error = $2, updated_at = $3 WHERE id = $1`
	_, err := s.pool.Exec(ctx, q, id, errMsg, time.Now().UTC())
	return err
}

// ResetStaleRankTasks moves rank tasks left in processing back to pending after a worker crash.
func (s *Store) ResetStaleRankTasks(ctx context.Context) (int64, error) {
	const q = `UPDATE rank_tasks SET state = 'pending', updated_at = $1 WHERE state = 'processing'`
	tag, err := s.pool.Exec(ctx, q, time.Now().UTC())
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

func (s *Store) RankStatusForJob(ctx context.Context, jobID uuid.UUID) (RankStatus, error) {
	const q = `
		SELECT
			COUNT(*) FILTER (WHERE state = 'pending') AS pending,
			COUNT(*) FILTER (WHERE state = 'processing') AS processing,
			COUNT(*) FILTER (WHERE state = 'done') AS done,
			COUNT(*) FILTER (WHERE state = 'failed') AS failed
		FROM rank_tasks
		WHERE job_id = $1
	`
	var st RankStatus
	if err := s.pool.QueryRow(ctx, q, jobID).Scan(&st.Pending, &st.Processing, &st.Done, &st.Failed); err != nil {
		return RankStatus{}, err
	}
	return st, nil
}

func (s *Store) UpsertScore(ctx context.Context, sc *Score) error {
	now := time.Now().UTC()
	if sc.ID == uuid.Nil {
		sc.ID = uuid.New()
	}
	sc.CreatedAt = now
	const q = `
		INSERT INTO scores (id, cv_id, job_id, score, subscores, evidence, one_pager, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT (cv_id, job_id) DO UPDATE SET
			score = EXCLUDED.score,
			subscores = EXCLUDED.subscores,
			evidence = EXCLUDED.evidence,
			one_pager = EXCLUDED.one_pager,
			created_at = EXCLUDED.created_at
	`
	_, err := s.pool.Exec(ctx, q, sc.ID, sc.CVID, sc.JobID, sc.Score, sc.Subscores, sc.Evidence, sc.OnePager, sc.CreatedAt)
	return err
}

func (s *Store) ListScoresByJob(ctx context.Context, jobID uuid.UUID, limit, offset int) ([]FeedItem, int64, error) {
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
	if err := s.pool.QueryRow(ctx, `SELECT COUNT(*) FROM scores WHERE job_id = $1`, jobID).Scan(&total); err != nil {
		return nil, 0, err
	}
	const q = `
		SELECT s.id, s.cv_id, s.job_id, s.score, s.subscores, s.evidence, s.one_pager, s.created_at,
		       c.id, c.title, c.original_filename, c.content_type, c.storage_key, c.sha256, c.size_bytes,
		       c.owner_id, c.status, c.parse_error, c.extracted_text, c.profile, c.profile_status, c.created_at, c.updated_at
		FROM scores s
		JOIN cvs c ON c.id = s.cv_id
		WHERE s.job_id = $1
		ORDER BY s.score DESC, s.created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := s.pool.Query(ctx, q, jobID, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	var list []FeedItem
	for rows.Next() {
		var sc Score
		var cv CV
		var ownerID *string
		var parseErr *string
		var extracted *string
		var status string
		var profileStatus string
		if err := rows.Scan(
			&sc.ID, &sc.CVID, &sc.JobID, &sc.Score, &sc.Subscores, &sc.Evidence, &sc.OnePager, &sc.CreatedAt,
			&cv.ID, &cv.Title, &cv.OriginalFilename, &cv.ContentType, &cv.StorageKey, &cv.SHA256, &cv.SizeBytes,
			&ownerID, &status, &parseErr, &extracted, &cv.Profile, &profileStatus, &cv.CreatedAt, &cv.UpdatedAt,
		); err != nil {
			return nil, 0, err
		}
		cv.OwnerID = ownerID
		cv.ParseError = parseErr
		cv.ExtractedText = extracted
		cv.Status = CVStatus(status)
		cv.ProfileStatus = ProfileStatus(profileStatus)
		list = append(list, FeedItem{CV: cv, Score: sc})
	}
	return list, total, rows.Err()
}

func (s *Store) AddReaction(ctx context.Context, r *Reaction) error {
	now := time.Now().UTC()
	if r.ID == uuid.Nil {
		r.ID = uuid.New()
	}
	r.CreatedAt = now
	const q = `INSERT INTO reactions (id, cv_id, job_id, exec_id, action, created_at) VALUES ($1, $2, $3, $4, $5, $6)`
	_, err := s.pool.Exec(ctx, q, r.ID, r.CVID, r.JobID, r.ExecID, r.Action, r.CreatedAt)
	return err
}

func (s *Store) ListReactions(ctx context.Context, cvID uuid.UUID) ([]Reaction, error) {
	const q = `SELECT id, cv_id, job_id, exec_id, action, created_at FROM reactions WHERE cv_id = $1 ORDER BY created_at DESC`
	rows, err := s.pool.Query(ctx, q, cvID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Reaction
	for rows.Next() {
		var r Reaction
		if err := rows.Scan(&r.ID, &r.CVID, &r.JobID, &r.ExecID, &r.Action, &r.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, r)
	}
	return list, rows.Err()
}

// ListReactionsByExec returns the latest reaction per (cv_id, job_id) for an exec.
func (s *Store) ListReactionsByExec(ctx context.Context, execID string, jobID *uuid.UUID, action *string) ([]Reaction, error) {
	const q = `
		SELECT DISTINCT ON (cv_id, COALESCE(job_id::text, ''))
			id, cv_id, job_id, exec_id, action, created_at
		FROM reactions
		WHERE COALESCE(exec_id, 'anonymous') = $1
		  AND ($2::uuid IS NULL OR job_id = $2)
		  AND ($3::text IS NULL OR action = $3)
		ORDER BY cv_id, COALESCE(job_id::text, ''), created_at DESC
	`
	rows, err := s.pool.Query(ctx, q, execID, jobID, action)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Reaction
	for rows.Next() {
		var r Reaction
		if err := rows.Scan(&r.ID, &r.CVID, &r.JobID, &r.ExecID, &r.Action, &r.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, r)
	}
	return list, rows.Err()
}

func (s *Store) GetReaction(ctx context.Context, id uuid.UUID) (*Reaction, error) {
	const q = `SELECT id, cv_id, job_id, exec_id, action, created_at FROM reactions WHERE id = $1`
	var r Reaction
	err := s.pool.QueryRow(ctx, q, id).Scan(&r.ID, &r.CVID, &r.JobID, &r.ExecID, &r.Action, &r.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &r, nil
}

func (s *Store) DeleteReaction(ctx context.Context, id uuid.UUID, execID string) error {
	const q = `DELETE FROM reactions WHERE id = $1 AND COALESCE(exec_id, 'anonymous') = $2`
	tag, err := s.pool.Exec(ctx, q, id, execID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) AddComment(ctx context.Context, c *Comment) error {
	now := time.Now().UTC()
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	c.CreatedAt = now
	const q = `INSERT INTO comments (id, cv_id, author, body, created_at) VALUES ($1, $2, $3, $4, $5)`
	_, err := s.pool.Exec(ctx, q, c.ID, c.CVID, c.Author, c.Body, c.CreatedAt)
	return err
}

func (s *Store) ListComments(ctx context.Context, cvID uuid.UUID) ([]Comment, error) {
	const q = `SELECT id, cv_id, author, body, created_at FROM comments WHERE cv_id = $1 ORDER BY created_at DESC`
	rows, err := s.pool.Query(ctx, q, cvID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Comment
	for rows.Next() {
		var c Comment
		if err := rows.Scan(&c.ID, &c.CVID, &c.Author, &c.Body, &c.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, c)
	}
	return list, rows.Err()
}

func (s *Store) Stats(ctx context.Context) ([]ExecStats, error) {
	const q = `
		SELECT COALESCE(exec_id, 'anonymous') AS exec_id,
		       COUNT(*) AS total,
		       COUNT(*) FILTER (WHERE action = 'like') AS likes,
		       COUNT(*) FILTER (WHERE action = 'shortlist') AS shortlists,
		       COUNT(*) FILTER (WHERE action = 'star') AS stars,
		       COUNT(*) FILTER (WHERE action = 'pass') AS passes
		FROM reactions
		GROUP BY COALESCE(exec_id, 'anonymous')
		ORDER BY total DESC
	`
	rows, err := s.pool.Query(ctx, q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []ExecStats
	for rows.Next() {
		var st ExecStats
		if err := rows.Scan(&st.ExecID, &st.TotalReviews, &st.Likes, &st.Shortlists, &st.Stars, &st.Passes); err != nil {
			return nil, err
		}
		st.StreakDays = s.streakDays(ctx, st.ExecID)
		list = append(list, st)
	}
	return list, rows.Err()
}

// PipelineStats aggregates counts across every processing stage so the UI can
// render a funnel: ingestion → text extraction → profile extraction → ranking.
func (s *Store) PipelineStats(ctx context.Context) (*PipelineStats, error) {
	var ps PipelineStats
	const cvQ = `
		SELECT
			COUNT(*),
			COUNT(*) FILTER (WHERE status = 'pending'),
			COUNT(*) FILTER (WHERE status = 'processing'),
			COUNT(*) FILTER (WHERE status = 'ready'),
			COUNT(*) FILTER (WHERE status = 'failed'),
			COUNT(*) FILTER (WHERE status = 'ready' AND profile_status = 'pending'),
			COUNT(*) FILTER (WHERE profile_status = 'processing'),
			COUNT(*) FILTER (WHERE profile_status = 'ready'),
			COUNT(*) FILTER (WHERE profile_status = 'failed')
		FROM cvs`
	if err := s.pool.QueryRow(ctx, cvQ).Scan(
		&ps.TotalCVs,
		&ps.Extraction.Pending, &ps.Extraction.Processing, &ps.Extraction.Ready, &ps.Extraction.Failed,
		&ps.Profile.Pending, &ps.Profile.Processing, &ps.Profile.Ready, &ps.Profile.Failed,
	); err != nil {
		return nil, err
	}

	const rankQ = `
		SELECT
			COUNT(*) FILTER (WHERE state = 'pending'),
			COUNT(*) FILTER (WHERE state = 'processing'),
			COUNT(*) FILTER (WHERE state = 'done'),
			COUNT(*) FILTER (WHERE state = 'failed')
		FROM rank_tasks`
	if err := s.pool.QueryRow(ctx, rankQ).Scan(
		&ps.Ranking.Pending, &ps.Ranking.Processing, &ps.Ranking.Done, &ps.Ranking.Failed,
	); err != nil {
		return nil, err
	}

	if err := s.pool.QueryRow(ctx, `SELECT COUNT(*) FILTER (WHERE kind = 'job'), COUNT(*) FILTER (WHERE kind = 'campaign') FROM jobs`).Scan(&ps.Jobs, &ps.Campaigns); err != nil {
		return nil, err
	}
	return &ps, nil
}

func (s *Store) streakDays(ctx context.Context, execID string) int {
	const q = `
		SELECT DISTINCT DATE(created_at AT TIME ZONE 'UTC') AS d
		FROM reactions
		WHERE COALESCE(exec_id, 'anonymous') = $1
		ORDER BY d DESC
	`
	rows, err := s.pool.Query(ctx, q, execID)
	if err != nil {
		return 0
	}
	defer rows.Close()
	var days []time.Time
	for rows.Next() {
		var d time.Time
		if err := rows.Scan(&d); err != nil {
			return 0
		}
		days = append(days, d)
	}
	if len(days) == 0 {
		return 0
	}
	streak := 1
	today := time.Now().UTC().Truncate(24 * time.Hour)
	if days[0].Truncate(24 * time.Hour).Before(today.Add(-24 * time.Hour)) {
		return 0
	}
	for i := 1; i < len(days); i++ {
		prev := days[i-1].Truncate(24 * time.Hour)
		cur := days[i].Truncate(24 * time.Hour)
		if prev.Sub(cur) == 24*time.Hour {
			streak++
		} else {
			break
		}
	}
	return streak
}

func (s *Store) CountReactionsForJob(ctx context.Context, jobID uuid.UUID, execID string) (int64, error) {
	var total int64
	err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM reactions
		WHERE job_id = $1 AND COALESCE(exec_id, 'anonymous') = $2
	`, jobID, execID).Scan(&total)
	return total, err
}

func profileName(profile json.RawMessage) string {
	if len(profile) == 0 {
		return ""
	}
	var p struct {
		Name string `json:"name"`
	}
	_ = json.Unmarshal(profile, &p)
	return p.Name
}

func profileSkills(profile json.RawMessage) string {
	if len(profile) == 0 {
		return ""
	}
	var p struct {
		Skills []string `json:"skills"`
	}
	_ = json.Unmarshal(profile, &p)
	return stringsJoin(p.Skills, ", ")
}

func profileLocation(profile json.RawMessage) string {
	if len(profile) == 0 {
		return ""
	}
	var p struct {
		Location string `json:"location"`
	}
	_ = json.Unmarshal(profile, &p)
	return p.Location
}

func stringsJoin(parts []string, sep string) string {
	if len(parts) == 0 {
		return ""
	}
	out := parts[0]
	for i := 1; i < len(parts); i++ {
		out += sep + parts[i]
	}
	return out
}
