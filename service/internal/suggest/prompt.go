package suggest

import (
	"encoding/json"
	"fmt"
)

const PromptVersion = "v1"

func BuildPrompt(input PromptInput) (string, error) {
	payload, err := json.Marshal(input)
	if err != nil {
		return "", err
	}

	prompt := fmt.Sprintf(`You are a careful categorization assistant.
Return ONLY one JSON object in one of these forms:

{"txn_id":"...","suggested":true,"category":"Food","subcategory":"Groceries","reason_code":"payee_match"}

OR

{"txn_id":"...","suggested":false,"reason":"insufficient_signal"}

Rules:
- Output must be valid JSON.
- Use only categories/subcategories from the provided allow-list.
- Do not include extra commentary or text.

Input JSON:
%s
`, string(payload))

	return prompt, nil
}
