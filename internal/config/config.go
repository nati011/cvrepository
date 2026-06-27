package config

import (
	"fmt"
	"os"
	"time"

	"gopkg.in/yaml.v3"
)

// Config holds runtime settings shared by the API and worker.
type Config struct {
	DatabaseURL          string
	CVStorageRoot        string
	HTTPAddr             string
	TikaURL              string
	MeiliHost            string
	MeiliAPIKey          string
	MeiliIndex           string
	GroqAPIKey           string
	GroqModel            string
	GroqBaseURL          string
	WorkerPollInterval   time.Duration
	BatchMaxRequestBytes int64
	BatchMaxFileBytes    int64
	BatchMaxFiles        int
}

type yamlFile struct {
	DatabaseURL          string `yaml:"database_url"`
	CVStorageRoot        string `yaml:"cv_storage_root"`
	HTTPAddr             string `yaml:"http_addr"`
	TikaURL              string `yaml:"tika_url"`
	MeiliHost            string `yaml:"meili_host"`
	MeiliAPIKey          string `yaml:"meili_api_key"`
	MeiliIndex           string `yaml:"meili_index"`
	GroqAPIKey           string `yaml:"groq_api_key"`
	GroqModel            string `yaml:"groq_model"`
	GroqBaseURL          string `yaml:"groq_base_url"`
	WorkerPollInterval   string `yaml:"worker_poll_interval"`
	BatchMaxRequestBytes int64  `yaml:"batch_max_request_bytes"`
	BatchMaxFileBytes    int64  `yaml:"batch_max_file_bytes"`
	BatchMaxFiles        int    `yaml:"batch_max_files"`
}

// LoadFile reads and validates configuration from a YAML file.
func LoadFile(path string) (Config, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return Config{}, fmt.Errorf("read config %q: %w", path, err)
	}
	var y yamlFile
	if err := yaml.Unmarshal(b, &y); err != nil {
		return Config{}, fmt.Errorf("parse config yaml: %w", err)
	}
	if y.DatabaseURL == "" {
		return Config{}, fmt.Errorf("database_url is required")
	}
	if y.CVStorageRoot == "" {
		return Config{}, fmt.Errorf("cv_storage_root is required")
	}
	poll := y.WorkerPollInterval
	if poll == "" {
		poll = "2s"
	}
	d, err := time.ParseDuration(poll)
	if err != nil {
		return Config{}, fmt.Errorf("worker_poll_interval: %w", err)
	}
	c := Config{
		DatabaseURL:          y.DatabaseURL,
		CVStorageRoot:        y.CVStorageRoot,
		HTTPAddr:             y.HTTPAddr,
		TikaURL:              y.TikaURL,
		MeiliHost:            y.MeiliHost,
		MeiliAPIKey:          y.MeiliAPIKey,
		MeiliIndex:           y.MeiliIndex,
		GroqAPIKey:           y.GroqAPIKey,
		GroqModel:            y.GroqModel,
		GroqBaseURL:          y.GroqBaseURL,
		WorkerPollInterval:   d,
		BatchMaxRequestBytes: y.BatchMaxRequestBytes,
		BatchMaxFileBytes:    y.BatchMaxFileBytes,
		BatchMaxFiles:        y.BatchMaxFiles,
	}
	if c.HTTPAddr == "" {
		c.HTTPAddr = ":8080"
	}
	if c.TikaURL == "" {
		c.TikaURL = "http://localhost:9998"
	}
	if c.MeiliHost == "" {
		c.MeiliHost = "http://localhost:7700"
	}
	if c.MeiliIndex == "" {
		c.MeiliIndex = "cvs"
	}
	if c.GroqAPIKey == "" {
		if v := os.Getenv("GROQ_API_KEY"); v != "" {
			c.GroqAPIKey = v
		}
	}
	if c.GroqModel == "" {
		c.GroqModel = "llama-3.3-70b-versatile"
	}
	if c.GroqBaseURL == "" {
		c.GroqBaseURL = "https://api.groq.com/openai/v1"
	}
	if c.BatchMaxRequestBytes == 0 {
		c.BatchMaxRequestBytes = 256 << 20
	}
	if c.BatchMaxFileBytes == 0 {
		c.BatchMaxFileBytes = 32 << 20
	}
	if c.BatchMaxFiles == 0 {
		c.BatchMaxFiles = 100
	}
	return c, nil
}
