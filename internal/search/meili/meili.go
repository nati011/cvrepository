package meili

import (
	"context"
	"encoding/json"
	"fmt"

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
	_, err := idx.UpdateSearchableAttributes(&[]string{"title", "original_filename", "body"})
	if err != nil {
		return nil, fmt.Errorf("meilisearch searchable attributes: %w", err)
	}
	_, err = idx.UpdateFilterableAttributes(&[]string{"owner_id", "created_at"})
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
	OwnerID          string `json:"owner_id,omitempty"`
	CreatedAt        int64  `json:"created_at"`
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
	d := doc{
		ID:               cv.ID.String(),
		Title:            cv.Title,
		OriginalFilename: cv.OriginalFilename,
		Body:             body,
		OwnerID:          owner,
		CreatedAt:        cv.CreatedAt.Unix(),
	}
	task, err := i.index.AddDocuments([]doc{d}, "id")
	if err != nil {
		return err
	}
	_, err = i.index.WaitForTask(task.TaskUID, meilisearch.WaitParams{Context: ctx})
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
	return nil
}
