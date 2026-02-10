package suggest

import (
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Enabled         bool
	Runtime         string
	ModelPath       string
	Timeout         time.Duration
	MaxConcurrency  int
	Temperature     float64
	CacheTTL        time.Duration
	MinConfidence   float64
	SyncMaxCount    int
	RetryMax        int
	PollInterval    time.Duration
	ModelID         string
}

func LoadConfig() Config {
	cfg := Config{
		Enabled:        getenvBool("LLM_ENABLED", false),
		Runtime:        getenv("LLM_RUNTIME", "llama_cpp"),
		ModelPath:      getenv("LLM_MODEL_PATH", ""),
		Timeout:        time.Duration(getenvInt("LLM_TIMEOUT_MS", 2000)) * time.Millisecond,
		MaxConcurrency: getenvInt("LLM_MAX_CONCURRENCY", 1),
		Temperature:    getenvFloat("LLM_TEMPERATURE", 0.0),
		CacheTTL:       time.Duration(getenvInt("LLM_CACHE_TTL_HOURS", 720)) * time.Hour,
		MinConfidence:  getenvFloat("LLM_MIN_CONFIDENCE", 0.70),
		SyncMaxCount:   getenvInt("LLM_SYNC_MAX", 20),
		RetryMax:       getenvInt("LLM_RETRY_MAX", 2),
		PollInterval:   time.Duration(getenvInt("LLM_POLL_INTERVAL_MS", 1500)) * time.Millisecond,
	}

	cfg.ModelID = modelIDFromPath(cfg.ModelPath)

	if strings.ToLower(cfg.Runtime) != "llama_cpp" {
		cfg.Enabled = false
	}
	if cfg.ModelPath == "" {
		cfg.Enabled = false
	}
	if cfg.MaxConcurrency <= 0 {
		cfg.MaxConcurrency = 1
	}
	if cfg.SyncMaxCount <= 0 {
		cfg.SyncMaxCount = 20
	}
	if cfg.RetryMax <= 0 {
		cfg.RetryMax = 2
	}
	if cfg.PollInterval <= 0 {
		cfg.PollInterval = 1500 * time.Millisecond
	}
	return cfg
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getenvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if parsed, err := strconv.Atoi(v); err == nil {
			return parsed
		}
	}
	return fallback
}

func getenvFloat(key string, fallback float64) float64 {
	if v := os.Getenv(key); v != "" {
		if parsed, err := strconv.ParseFloat(v, 64); err == nil {
			return parsed
		}
	}
	return fallback
}

func getenvBool(key string, fallback bool) bool {
	if v := os.Getenv(key); v != "" {
		switch strings.ToLower(v) {
		case "1", "true", "yes", "y":
			return true
		case "0", "false", "no", "n":
			return false
		}
	}
	return fallback
}

func modelIDFromPath(path string) string {
	if path == "" {
		return ""
	}
	for i := len(path) - 1; i >= 0; i-- {
		if path[i] == '\\' || path[i] == '/' {
			return path[i+1:]
		}
	}
	return path
}
