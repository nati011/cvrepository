package pgstore

import (
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
	CreatedAt        time.Time
	UpdatedAt        time.Time
}
