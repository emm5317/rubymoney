package suggest

import (
	"context"
	"time"
)

type Adapter interface {
	SuggestCategory(ctx context.Context, prompt string) (string, time.Duration, error)
	ModelID() string
}
