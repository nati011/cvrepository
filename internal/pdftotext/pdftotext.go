package pdftotext

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
)

// Client extracts text from PDFs using the pdftotext CLI (poppler).
type Client struct{}

func New() *Client {
	return &Client{}
}

func (c *Client) ExtractText(ctx context.Context, contentType string, r io.Reader) (string, error) {
	_ = contentType
	tmp, err := os.CreateTemp("", "cvrepo-*.pdf")
	if err != nil {
		return "", err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	if _, err := io.Copy(tmp, r); err != nil {
		tmp.Close()
		return "", err
	}
	if err := tmp.Close(); err != nil {
		return "", err
	}
	outPath := tmpPath + ".txt"
	defer os.Remove(outPath)
	cmd := exec.CommandContext(ctx, "pdftotext", "-layout", filepath.Clean(tmpPath), outPath)
	if out, err := cmd.CombinedOutput(); err != nil {
		return "", fmt.Errorf("pdftotext: %w: %s", err, string(out))
	}
	b, err := os.ReadFile(outPath)
	if err != nil {
		return "", err
	}
	return string(b), nil
}
