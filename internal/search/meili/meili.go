package meili

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/meilisearch/meilisearch-go"

	pgstore "cvrepo/internal/store/pg"
)

type Index struct {
	client *meilisearch.Client
	index  *meilisearch.Index
	name   string
}

func New(host, apiKey, indexName string) (*Index, error) {
	client := meilisearch.NewClient(meilisearch.ClientConfig{
		Host:   host,
		APIKey: apiKey,
	})
	idx := client.Index(indexName)
	i := &Index{client: client, index: idx, name: indexName}
	if task, err := client.CreateIndex(&meilisearch.IndexConfig{
		Uid:        indexName,
		PrimaryKey: "id",
	}); err == nil && task != nil {
		_, _ = client.WaitForTask(task.TaskUID)
	}
	_, err := idx.UpdateSearchableAttributes(&[]string{"title", "original_filename", "body", "name", "skills", "location"})
	if err != nil {
		return nil, fmt.Errorf("meilisearch searchable attributes: %w", err)
	}
	_, err = idx.UpdateFilterableAttributes(&[]string{"owner_id", "created_at", "location"})
	if err != nil {
		return nil, fmt.Errorf("meilisearch filterable attributes: %w", err)
	}
	return i, nil
}

type doc struct {
	ID               string `json:"id"`
	Title            string `json:"title"`
	OriginalFilename string `json:"original_filename"`
	Body             string `json:"body"`
	Name             string `json:"name,omitempty"`
	Skills           string `json:"skills,omitempty"`
	Location         string `json:"location,omitempty"`
	OwnerID          string `json:"owner_id,omitempty"`
	CreatedAt        int64  `json:"created_at"`
}

func profileFields(profile []byte) (name, skills, location string) {
	if len(profile) == 0 {
		return "", "", ""
	}
	var p struct {
		Name     string   `json:"name"`
		Skills   []string `json:"skills"`
		Location string   `json:"location"`
	}
	if err := json.Unmarshal(profile, &p); err != nil {
		return "", "", ""
	}
	name = p.Name
	location = p.Location
	for i, sk := range p.Skills {
		if i > 0 {
			skills += ", "
		}
		skills += sk
	}
	return name, skills, location
}

func (i *Index) IndexCV(ctx context.Context, cv *pgstore.CV) error {
	owner := ""
	if cv.OwnerID != nil {
		owner = *cv.OwnerID
	}
	body := ""
	if cv.ExtractedText != nil {
		body = *cv.ExtractedText
	}
	name, skills, location := profileFields(cv.Profile)
	d := doc{
		ID:               cv.ID.String(),
		Title:            cv.Title,
		OriginalFilename: cv.OriginalFilename,
		Body:             body,
		Name:             name,
		Skills:           skills,
		Location:         location,
		OwnerID:          owner,
		CreatedAt:        cv.CreatedAt.Unix(),
	}
	task, err := i.index.AddDocuments([]doc{d}, "id")
	if err != nil {
		return err
	}
	_, err = i.index.WaitForTask(task.TaskUID, meilisearch.WaitParams{Context: ctx, Interval: 50 * time.Millisecond})
	return err
}

func (i *Index) Delete(ctx context.Context, id uuid.UUID) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	_, err := i.index.DeleteDocument(id.String())
	return err
}

type Hit struct {
	ID               string `json:"id"`
	Title            string `json:"title"`
	OriginalFilename string `json:"original_filename"`
	Name             string `json:"name,omitempty"`
	Skills           string `json:"skills,omitempty"`
	Location         string `json:"location,omitempty"`
}

type SearchResult struct {
	Hits []Hit
}

func (i *Index) Search(ctx context.Context, q string, limit int64) (*SearchResult, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	resp, err := i.index.Search(q, &meilisearch.SearchRequest{
		Limit: limit,
	})
	if err != nil {
		return nil, err
	}
	out := &SearchResult{Hits: make([]Hit, 0, len(resp.Hits))}
	for _, h := range resp.Hits {
		var hd doc
		if err := decodeHit(h, &hd); err != nil {
			continue
		}
		out.Hits = append(out.Hits, Hit{
			ID:               hd.ID,
			Title:            hd.Title,
			OriginalFilename: hd.OriginalFilename,
			Name:             hd.Name,
			Skills:           hd.Skills,
			Location:         hd.Location,
		})
	}
	return out, nil
}

func decodeHit(h interface{}, dst *doc) error {
	switch v := h.(type) {
	case map[string]interface{}:
		return mapToDoc(v, dst)
	default:
		b, err := json.Marshal(h)
		if err != nil {
			return err
		}
		return json.Unmarshal(b, dst)
	}
}

func mapToDoc(m map[string]interface{}, dst *doc) error {
	if v, ok := m["id"].(string); ok {
		dst.ID = v
	}
	if v, ok := m["title"].(string); ok {
		dst.Title = v
	}
	if v, ok := m["original_filename"].(string); ok {
		dst.OriginalFilename = v
	}
	if v, ok := m["name"].(string); ok {
		dst.Name = v
	}
	if v, ok := m["skills"].(string); ok {
		dst.Skills = v
	}
	if v, ok := m["location"].(string); ok {
		dst.Location = v
	}
	return nil
}
