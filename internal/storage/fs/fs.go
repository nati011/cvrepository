package fsstorage

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
)

type Store struct {
	root string
}

func New(root string) (*Store, error) {
	abs, err := filepath.Abs(root)
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(abs, 0o750); err != nil {
		return nil, err
	}
	return &Store{root: abs}, nil
}

func (s *Store) absPath(storageKey string) (string, error) {
	if storageKey == "" || strings.Contains(storageKey, "..") {
		return "", fmt.Errorf("invalid storage key")
	}
	clean := filepath.Clean(storageKey)
	if clean == "." || strings.HasPrefix(clean, "..") {
		return "", fmt.Errorf("invalid storage key")
	}
	full := filepath.Join(s.root, clean)
	rootWithSep := s.root + string(os.PathSeparator)
	if !strings.HasPrefix(full+string(os.PathSeparator), rootWithSep) && full != s.root {
		return "", fmt.Errorf("path escapes root")
	}
	return full, nil
}

func (s *Store) SavePDF(id uuid.UUID, originalName string, r io.Reader) (storageKey string, sha256hex string, size int64, err error) {
	base := filepath.Base(originalName)
	if base == "" || base == "." || base == string(filepath.Separator) {
		base = "document.pdf"
	}
	if !strings.HasSuffix(strings.ToLower(base), ".pdf") {
		base += ".pdf"
	}
	storageKey = filepath.Join(id.String(), base)
	full, err := s.absPath(storageKey)
	if err != nil {
		return "", "", 0, err
	}
	if err := os.MkdirAll(filepath.Dir(full), 0o750); err != nil {
		return "", "", 0, err
	}
	tmp, err := os.CreateTemp(filepath.Dir(full), ".upload-*")
	if err != nil {
		return "", "", 0, err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)

	h := sha256.New()
	mw := io.MultiWriter(tmp, h)
	n, err := io.Copy(mw, r)
	if err != nil {
		tmp.Close()
		return "", "", 0, err
	}
	if err := tmp.Close(); err != nil {
		return "", "", 0, err
	}
	if err := os.Rename(tmpPath, full); err != nil {
		return "", "", 0, err
	}
	sum := hex.EncodeToString(h.Sum(nil))
	return filepath.ToSlash(storageKey), sum, n, nil
}

func (s *Store) Open(storageKey string) (*os.File, error) {
	full, err := s.absPath(storageKey)
	if err != nil {
		return nil, err
	}
	return os.Open(full)
}

// Remove deletes the stored PDF and its parent directory when the key is uuid/filename.pdf
// (the layout produced by SavePDF). Top-level keys remove only that file.
func (s *Store) Remove(storageKey string) error {
	keySlash := filepath.ToSlash(storageKey)
	dirRel := filepath.ToSlash(filepath.Dir(keySlash))
	if dirRel == "." || dirRel == "" {
		full, err := s.absPath(storageKey)
		if err != nil {
			return err
		}
		if err := os.Remove(full); err != nil && !os.IsNotExist(err) {
			return err
		}
		return nil
	}
	dirFull, err := s.absPath(dirRel)
	if err != nil {
		return err
	}
	if err := os.RemoveAll(dirFull); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}
