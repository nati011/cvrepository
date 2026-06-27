package pgstore

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

type CVStatus string

const (
	StatusPending    CVStatus = "pending"
	StatusProcessing CVStatus = "processing"
	StatusReady      CVStatus = "ready"
	StatusFailed     CVStatus = "failed"
)

type ProfileStatus string

const (
	ProfilePending    ProfileStatus = "pending"
	ProfileProcessing ProfileStatus = "processing"
	ProfileReady      ProfileStatus = "ready"
	ProfileFailed     ProfileStatus = "failed"
)

type CV struct {
	ID               uuid.UUID
	Title            string
	OriginalFilename string
	ContentType      string
	StorageKey       string
	SHA256           string
	SizeBytes        int64
	OwnerID          *string
	Status           CVStatus
	ParseError       *string
	ExtractedText    *string
	Profile          json.RawMessage
	ProfileStatus    ProfileStatus
	CreatedAt        time.Time
	UpdatedAt        time.Time
}

type CampaignStatus string

const (
	CampaignDraft    CampaignStatus = "draft"
	CampaignActive   CampaignStatus = "active"
	CampaignPaused   CampaignStatus = "paused"
	CampaignClosed   CampaignStatus = "closed"
	CampaignArchived CampaignStatus = "archived"
)

func ValidCampaignStatus(s string) bool {
	switch CampaignStatus(s) {
	case CampaignDraft, CampaignActive, CampaignPaused, CampaignClosed, CampaignArchived:
		return true
	default:
		return false
	}
}

func CampaignAllowsAutoRank(s CampaignStatus) bool {
	return s == CampaignActive
}

func CampaignAllowsManualRank(s CampaignStatus) bool {
	switch s {
	case CampaignDraft, CampaignActive, CampaignPaused:
		return true
	default:
		return false
	}
}

func CampaignAllowsDeactivation(s CampaignStatus) bool {
	switch s {
	case CampaignDraft, CampaignActive, CampaignPaused:
		return true
	default:
		return false
	}
}

func CampaignIsDeactivated(s CampaignStatus) bool {
	return s == CampaignClosed || s == CampaignArchived
}

type JobKind string

const (
	JobKindDefinition JobKind = "job"
	JobKindCampaign   JobKind = "campaign"
)

func ValidJobKind(s string) bool {
	switch JobKind(s) {
	case JobKindDefinition, JobKindCampaign:
		return true
	default:
		return false
	}
}

// Job is a persisted role definition or hiring campaign (stored in the jobs table).
type Job struct {
	ID             uuid.UUID
	Kind           JobKind
	Title          string
	JDText         string
	Status         CampaignStatus
	Client         string
	HiringManager  string
	Location       string
	Headcount      *int
	StartDate      *time.Time
	EndDate        *time.Time
	Tags           []string
	OwnerID        *string
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

type CampaignListFilter struct {
	Status *CampaignStatus
	Client string
	Tag    string
}

type ReactionCounts struct {
	Shortlist int64 `json:"shortlist"`
	Star      int64 `json:"star"`
	Pass      int64 `json:"pass"`
}

type CampaignStats struct {
	RankedCount   int64          `json:"ranked_count"`
	RankStatus    RankStatus     `json:"rank_status"`
	Reactions     ReactionCounts `json:"reactions"`
	AvgScore      *float64       `json:"avg_score,omitempty"`
	TopScore      *int           `json:"top_score,omitempty"`
	ReviewedCount int64          `json:"reviewed_count"`
}

type Score struct {
	ID        uuid.UUID
	CVID      uuid.UUID
	JobID     uuid.UUID
	Score     int
	Subscores json.RawMessage
	Evidence  json.RawMessage
	OnePager  json.RawMessage
	CreatedAt time.Time
}

type FeedItem struct {
	CV    CV
	Score Score
}

type Reaction struct {
	ID        uuid.UUID
	CVID      uuid.UUID
	JobID     *uuid.UUID
	ExecID    *string
	Action    string
	CreatedAt time.Time
}

type Comment struct {
	ID        uuid.UUID
	CVID      uuid.UUID
	Author    string
	Body      string
	CreatedAt time.Time
}

type RankTask struct {
	ID        uuid.UUID
	CVID      uuid.UUID
	JobID     uuid.UUID
	State     string
	Error     *string
	CreatedAt time.Time
	UpdatedAt time.Time
}

type RankStatus struct {
	Pending    int `json:"pending"`
	Processing int `json:"processing"`
	Done       int `json:"done"`
	Failed     int `json:"failed"`
}

// StageCounts is the standard pending/processing/ready/failed breakdown used
// for the text-extraction and profile-extraction pipeline stages.
type StageCounts struct {
	Pending    int64 `json:"pending"`
	Processing int64 `json:"processing"`
	Ready      int64 `json:"ready"`
	Failed     int64 `json:"failed"`
}

// RankCounts is the ranking-stage breakdown (rank_tasks states).
type RankCounts struct {
	Pending    int64 `json:"pending"`
	Processing int64 `json:"processing"`
	Done       int64 `json:"done"`
	Failed     int64 `json:"failed"`
}

// PipelineStats summarizes how documents flow through every processing stage.
type PipelineStats struct {
	TotalCVs   int64       `json:"total_cvs"`
	Extraction StageCounts `json:"extraction"`
	Profile    StageCounts `json:"profile"`
	Ranking    RankCounts  `json:"ranking"`
	Jobs       int64       `json:"jobs"`
	Campaigns  int64       `json:"campaigns"`
}

type ExecStats struct {
	ExecID       string
	TotalReviews int
	Likes        int
	Shortlists   int
	Stars        int
	Passes       int
	StreakDays   int
}
