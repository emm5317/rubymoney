# Frontend Design Principles

This document defines the design system for all views, partials, and frontend code. Follow these patterns exactly to maintain visual consistency.

## Layout & Spacing

- **Page container:** `max-w-7xl mx-auto px-4 py-8` (list and detail pages)
- **Form container:** `max-w-2xl mx-auto px-4 py-8` (new/edit pages)
- **Page title:** `text-2xl font-bold text-gray-900 mb-6`
- **Section title:** `text-lg font-semibold text-gray-900 mb-4`
- **Page header row:** `flex justify-between items-center mb-6` (title left, actions right)

## Cards

- **Standard card:** `bg-white shadow rounded-lg p-6`
- **Card with table:** `bg-white shadow rounded-lg overflow-hidden` (no padding, table fills card)
- **Detail card (show pages):** `bg-white shadow rounded-lg p-6` with `<dl>` grid inside

## Tables

- **Wrapper:** Inside `bg-white shadow rounded-lg overflow-hidden`
- **Table:** `min-w-full divide-y divide-gray-200`
- **Header row:** `bg-gray-50`
- **Header cell:** `px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider`
- **Header cell (right-aligned):** Add `text-right` for amounts and actions columns
- **Body:** `bg-white divide-y divide-gray-200`
- **Body row:** `<%= index.even? ? 'bg-white' : 'bg-gray-50' %> hover:bg-gray-100 transition-colors`
- **Body cell:** `px-6 py-4 whitespace-nowrap text-sm`
- **Cell text colors:** `text-gray-900` for primary data, `text-gray-500` for secondary data
- **Name links:** `text-indigo-600 hover:text-indigo-900`
- **Action links (right-aligned):** `text-right text-sm` with `text-indigo-600 hover:text-indigo-900`

### Empty States

Every index page must handle the empty case:
```erb
<% if @collection.any? %>
  <%# table %>
<% else %>
  <div class="bg-white shadow rounded-lg p-8 text-center">
    <p class="text-gray-500">No items yet.</p>
    <%= link_to "Create your first item", new_path, class: "mt-2 inline-block text-indigo-600 hover:text-indigo-900" %>
  </div>
<% end %>
```

## Buttons

- **Primary:** `inline-flex items-center px-4 py-2 bg-indigo-600 text-white font-medium rounded-md hover:bg-indigo-700`
- **Secondary:** `inline-flex items-center px-4 py-2 border border-gray-300 text-gray-700 font-medium rounded-md hover:bg-gray-50`
- **Danger:** `inline-flex items-center px-4 py-2 bg-red-600 text-white font-medium rounded-md hover:bg-red-700`
- **Confirm (green):** `inline-flex items-center px-4 py-2 bg-green-600 text-white font-medium rounded-md hover:bg-green-700`
- **Submit (form):** Same as Primary, add `cursor-pointer`
- **Delete actions:** Always use `button_to` (never `link_to method: :delete`) for Turbo compatibility

## Forms

- **Card wrapper:** Form partials include `<div class="bg-white shadow rounded-lg p-6">` wrapping the form
- **Form tag:** `form_with(model: ..., class: "space-y-6")`
- **Labels:** `block text-sm font-medium text-gray-700`
- **Text inputs / selects:** `mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm`
- **Color picker:** `mt-1 h-10 w-20 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500`
- **Checkboxes:** `rounded border-gray-300 text-indigo-600 focus:ring-indigo-500`
- **Help text:** `mt-1 text-xs text-gray-500`
- **Grid layouts:** `grid grid-cols-1 sm:grid-cols-2 gap-6` for side-by-side fields

### Validation Errors

```erb
<% if record.errors.any? %>
  <div class="bg-red-50 border border-red-200 rounded-md p-4">
    <h3 class="text-sm font-medium text-red-800">
      <%= pluralize(record.errors.count, "error") %> prohibited this record from being saved:
    </h3>
    <ul class="mt-2 text-sm text-red-700 list-disc list-inside">
      <% record.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

### Back Links

Every new/edit page includes a back link below the form:
```erb
<div class="mt-4">
  <%= link_to "Back to ...", path, class: "text-indigo-600 hover:text-indigo-900 text-sm" %>
</div>
```

## Colors

### Brand

- **Primary:** Indigo-600 (actions, links, active nav, focus rings)
- **Primary hover:** Indigo-700
- **Primary light:** Indigo-200 (inactive nav text)
- **Nav background:** Indigo-700, active item: Indigo-800

### Semantic

- **Success / Credit:** Green-600 (text), Green-100/800 (badge)
- **Danger / Debit:** Red-600 (text), Red-100/800 (badge)
- **Warning / Pending:** Yellow-100/800 (badge)
- **Info / Processing:** Blue-100/800 (badge)
- **Neutral:** Gray-100/800 (default badge)

### Money Display

- Debits: `text-red-600`
- Credits: `text-green-600`
- Always use `number_to_currency()` — never raw `$` formatting
- Font weight: `font-semibold` for emphasized amounts

## Status Badges

Use the helpers in `ApplicationHelper`:
- `transaction_status_badge(status)` — pending (yellow), cleared (green), reconciled (blue)
- `import_status_badge(status)` — completed (green), failed (red), processing (blue), previewing (yellow)
- `category_label(category)` — name with color dot, or "Uncategorized" in muted italic
- `recurring_frequency_badge(frequency)` — weekly (blue), biweekly (cyan), monthly (indigo), quarterly (purple), annual (pink)
- `recurring_status_badge(status)` — active (green), missed (red), paused (yellow), cancelled (gray)
- `format_cents(cents)` — converts integer cents to `number_to_currency`
- `sort_link(column, label)` — sortable table header link with arrow indicator
- `sort_indicator(column)` — arrow glyph for active sort column

Badge base style: `px-2 py-1 text-xs rounded-full`

## Category & Tag Indicators

- **Category color dot:** `w-2 h-2 rounded-full mr-1.5` (in-table), `w-3 h-3 rounded-full mr-2` (in list links)
- **Tag pills:** `inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium` with dynamic background: `style="background-color: #{color}20; color: #{color};"`

## Navigation

- Active nav item: `bg-indigo-800 text-white`
- Inactive nav item: `text-indigo-200 hover:text-white hover:bg-indigo-600`
- All nav items: `px-3 py-2 rounded-md text-sm font-medium`

## Flash Messages

- Dismissible with close button (inline SVG X icon)
- Success: `bg-green-50 border border-green-200` with `text-green-800`
- Error: `bg-red-50 border border-red-200` with `text-red-800`

## Interactive Patterns

### Inline Editing (Stimulus: `inline_edit`)
- Display mode: clickable text, `cursor-pointer`
- Edit mode: `<select>` with `change->inline-edit#submit` for auto-submit
- Used for: category assignment in transaction tables

### Bulk Selection (Stimulus: `bulk_select`)
- Checkbox column as first column in table
- Checkbox style: `rounded border-gray-300 text-indigo-600 focus:ring-indigo-500`
- Sticky bottom bar: `fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 shadow-lg z-50`

### Turbo

- Delete actions: Always `button_to ... method: :delete` (never `link_to method: :delete`)
- Non-GET link actions: Use `data: { turbo_method: :post }` on `link_to`
- Inline updates: Turbo Frames with `turbo_frame_tag` per component

## What NOT to Do

- Never use `link_to` with `method: :delete` — use `button_to` for Turbo
- Never use raw `$` formatting for money — always `number_to_currency()`
- Never use `string == 'value'` for enums — use predicate methods (`debit?`, `pending?`)
- Never use `space-y-4` in forms — always `space-y-6`
- Never omit `tracking-wider` from table headers
- Never omit hover states from table rows
- Never omit empty states from index pages
- Never omit the card wrapper (`bg-white shadow rounded-lg p-6`) from form partials
- Never omit back links from new/edit pages
- Never omit focus ring styles (`focus:border-indigo-500 focus:ring-indigo-500`) from form inputs
