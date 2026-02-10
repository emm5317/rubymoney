package suggest

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"time"
)

type LlamaAdapter struct {
	modelPath   string
	temperature float64
	timeout     time.Duration
	modelID     string
	binary      string
	maxTokens   int
}

func NewLlamaAdapter(cfg Config) *LlamaAdapter {
	bin := "llama-cli"
	if _, err := exec.LookPath(bin); err != nil {
		if alt, err := exec.LookPath("llama"); err == nil {
			bin = alt
		}
	}
	return &LlamaAdapter{
		modelPath:   cfg.ModelPath,
		temperature: cfg.Temperature,
		timeout:     cfg.Timeout,
		modelID:     cfg.ModelID,
		binary:      bin,
		maxTokens:   256,
	}
}

func (l *LlamaAdapter) ModelID() string {
	return l.modelID
}

func (l *LlamaAdapter) SuggestCategory(ctx context.Context, prompt string) (string, time.Duration, error) {
	if l.modelPath == "" {
		return "", 0, fmt.Errorf("model path is empty")
	}
	if l.binary == "" {
		return "", 0, fmt.Errorf("llama binary is empty")
	}

	runCtx, cancel := context.WithTimeout(ctx, l.timeout)
	defer cancel()

	args := []string{
		"-m", l.modelPath,
		"-p", prompt,
		"-n", fmt.Sprintf("%d", l.maxTokens),
		"--temp", fmt.Sprintf("%.2f", l.temperature),
	}

	cmd := exec.CommandContext(runCtx, l.binary, args...)
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	start := time.Now()
	if err := cmd.Run(); err != nil {
		return "", time.Since(start), fmt.Errorf("llama-cli failed: %w (%s)", err, stderr.String())
	}

	return stdout.String(), time.Since(start), nil
}
