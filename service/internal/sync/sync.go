package syncer

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
)

func NormalizeString(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	value = strings.ReplaceAll(value, "\t", " ")
	value = strings.ReplaceAll(value, "\n", " ")
	value = strings.Join(strings.Fields(value), " ")
	return value
}

func Fingerprint(accountID, postedDate string, amount float64, payee, memo string) string {
	normalizedPayee := NormalizeString(payee)
	normalizedMemo := NormalizeString(memo)
	amountStr := fmt.Sprintf("%.2f", amount)
	raw := strings.Join([]string{accountID, postedDate, amountStr, normalizedPayee, normalizedMemo}, "|")
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}
