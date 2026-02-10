package suggest

import (
	"encoding/json"
	"errors"
	"fmt"
)

func ParseModelResponse(expectedTxnID string, raw string) (ModelResponse, error) {
	jsonStr := extractFirstJSONObject(raw)
	if jsonStr == "" {
		return ModelResponse{}, errors.New("no JSON object found")
	}

	var resp ModelResponse
	if err := json.Unmarshal([]byte(jsonStr), &resp); err != nil {
		return ModelResponse{}, fmt.Errorf("invalid JSON: %w", err)
	}
	if expectedTxnID != "" && resp.TxnID != "" && resp.TxnID != expectedTxnID {
		return ModelResponse{}, fmt.Errorf("txn_id mismatch: %s", resp.TxnID)
	}
	if resp.TxnID == "" && expectedTxnID != "" {
		resp.TxnID = expectedTxnID
	}
	return resp, nil
}

func extractFirstJSONObject(raw string) string {
	inString := false
	escape := false
	depth := 0
	start := -1

	for i, r := range raw {
		switch r {
		case '"':
			if !escape {
				inString = !inString
			}
			escape = false
		case '\\':
			if inString {
				escape = !escape
			}
		case '{':
			if inString {
				escape = false
				continue
			}
			if depth == 0 {
				start = i
			}
			depth++
			escape = false
		case '}':
			if inString {
				escape = false
				continue
			}
			if depth > 0 {
				depth--
				if depth == 0 && start >= 0 {
					return raw[start : i+1]
				}
			}
			escape = false
		default:
			escape = false
		}
	}
	return ""
}
