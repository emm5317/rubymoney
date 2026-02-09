package logging

import "strings"

// RedactString applies a minimal redaction to avoid leaking obvious secrets.
// Expand this as new secret fields are introduced.
func RedactString(s string) string {
	lower := strings.ToLower(s)
	if strings.Contains(lower, "token") || strings.Contains(lower, "secret") || strings.Contains(lower, "password") {
		return "[redacted]"
	}
	return s
}
