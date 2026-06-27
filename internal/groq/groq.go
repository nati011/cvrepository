package groq

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const defaultBaseURL = "https://api.groq.com/openai/v1"
const defaultModel = "llama-3.3-70b-versatile"

// maxRetries is the number of additional attempts on transient failures
// (HTTP 429 and 5xx, or network errors).
const maxRetries = 3

type Client struct {
	apiKey     string
	baseURL    string
	model      string
	httpClient *http.Client
}

func New(apiKey, baseURL, model string) *Client {
	if baseURL == "" {
		baseURL = defaultBaseURL
	}
	baseURL = strings.TrimRight(baseURL, "/")
	if model == "" {
		model = defaultModel
	}
	return &Client{
		apiKey:  apiKey,
		baseURL: baseURL,
		model:   model,
		httpClient: &http.Client{
			Timeout: 120 * time.Second,
		},
	}
}

type chatRequest struct {
	Model          string          `json:"model"`
	Messages       []chatMessage   `json:"messages"`
	ResponseFormat *responseFormat `json:"response_format,omitempty"`
	Temperature    float64         `json:"temperature"`
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type responseFormat struct {
	Type string `json:"type"`
}

type chatResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
	Error *struct {
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

func (c *Client) Complete(ctx context.Context, systemPrompt, userPrompt string, jsonMode bool) (string, error) {
	if c.apiKey == "" {
		return "", fmt.Errorf("groq: api key not configured")
	}
	reqBody := chatRequest{
		Model: c.model,
		Messages: []chatMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: userPrompt},
		},
		Temperature: 0.1,
	}
	if jsonMode {
		reqBody.ResponseFormat = &responseFormat{Type: "json_object"}
	}
	b, err := json.Marshal(reqBody)
	if err != nil {
		return "", err
	}
	var lastErr error
	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			backoff := time.Duration(1<<uint(attempt-1)) * 500 * time.Millisecond
			select {
			case <-ctx.Done():
				return "", ctx.Err()
			case <-time.After(backoff):
			}
		}
		content, retryable, reqErr := c.doRequest(ctx, b)
		if reqErr == nil {
			return content, nil
		}
		lastErr = reqErr
		if !retryable {
			return "", reqErr
		}
	}
	return "", fmt.Errorf("groq: exhausted retries: %w", lastErr)
}

// doRequest performs a single request attempt. The boolean reports whether the
// error (if any) is transient and worth retrying.
func (c *Client) doRequest(ctx context.Context, body []byte) (string, bool, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/chat/completions", bytes.NewReader(body))
	if err != nil {
		return "", false, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	resp, err := c.httpClient.Do(req)
	if err != nil {
		if ctx.Err() != nil {
			return "", false, err
		}
		return "", true, err
	}
	defer resp.Body.Close()
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", true, err
	}
	if resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode >= 500 {
		return "", true, fmt.Errorf("groq: status %d: %s", resp.StatusCode, strings.TrimSpace(string(respBody)))
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", false, fmt.Errorf("groq: status %d: %s", resp.StatusCode, strings.TrimSpace(string(respBody)))
	}
	var out chatResponse
	if err := json.Unmarshal(respBody, &out); err != nil {
		return "", false, err
	}
	if out.Error != nil {
		return "", false, fmt.Errorf("groq: %s", out.Error.Message)
	}
	if len(out.Choices) == 0 {
		return "", false, fmt.Errorf("groq: empty response")
	}
	return strings.TrimSpace(out.Choices[0].Message.Content), false, nil
}
