package suggest

import "strings"

type AllowList struct {
	categories map[string]allowCategory
}

type allowCategory struct {
	name        string
	subcategories map[string]string
}

func BuildAllowList(categories []CategoryAllowList) AllowList {
	out := AllowList{categories: map[string]allowCategory{}}
	for _, cat := range categories {
		name := strings.TrimSpace(cat.Name)
		if name == "" {
			continue
		}
		key := strings.ToLower(name)
		entry, ok := out.categories[key]
		if !ok {
			entry = allowCategory{name: name, subcategories: map[string]string{}}
		}
		for _, sub := range cat.Subcategories {
			subName := strings.TrimSpace(sub)
			if subName == "" {
				continue
			}
			entry.subcategories[strings.ToLower(subName)] = subName
		}
		out.categories[key] = entry
	}
	return out
}

func (a AllowList) IsValid(category, subcategory string) bool {
	if category == "" {
		return false
	}
	key := strings.ToLower(strings.TrimSpace(category))
	entry, ok := a.categories[key]
	if !ok {
		return false
	}
	if len(entry.subcategories) == 0 {
		return strings.TrimSpace(subcategory) == ""
	}
	_, ok = entry.subcategories[strings.ToLower(strings.TrimSpace(subcategory))]
	return ok
}

func (a AllowList) CategoryNames() []string {
	out := make([]string, 0, len(a.categories))
	for _, entry := range a.categories {
		out = append(out, entry.name)
	}
	return out
}

func (a AllowList) Canonical(category, subcategory string) (string, string, bool) {
	if category == "" {
		return "", "", false
	}
	key := strings.ToLower(strings.TrimSpace(category))
	entry, ok := a.categories[key]
	if !ok {
		return "", "", false
	}
	if len(entry.subcategories) == 0 {
		if strings.TrimSpace(subcategory) == "" {
			return entry.name, "", true
		}
		return "", "", false
	}
	subKey := strings.ToLower(strings.TrimSpace(subcategory))
	sub, ok := entry.subcategories[subKey]
	if !ok {
		return "", "", false
	}
	return entry.name, sub, true
}
