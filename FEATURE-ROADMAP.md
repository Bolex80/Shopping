# Bentomo Shopping — Feature Roadmap

> Detailed implementation plans for future development sessions.
> Priority ordered by impact on daily grocery use and implementation complexity.

---

## 1. Price Tracking (High Impact, Medium Effort)

### Goal
Allow users to optionally add a price to each item, then show a running total at the bottom of each list.

### Database Changes
```sql
ALTER TABLE items ADD COLUMN price REAL DEFAULT 0;
ALTER TABLE items ADD COLUMN currency TEXT DEFAULT '';
```

### Backend Changes
- **`db/queries.go`**: Update `CreateItem`, `CreateItemTx`, `UpdateItem` to accept `price` and `currency` fields
- **`db/queries.go`**: Add `GetListTotal(listID int64) (total float64, currency string)` — aggregates `SUM(price * quantity)` for all non-completed items in a list
- **`handlers/items.go`**: Accept `price` in create/update request bodies
- **`handlers/lists.go`**: Add `/lists/:id/total` endpoint returning the total

### Frontend Changes
- **`templates/partials/item.html`**: Add an optional price input field (initially hidden, toggled by a "$" button). Shows as `€2.50` tag next to item description
- **`templates/partials/item_completed.html`**: Show price next to completed items (strikethrough)
- **`templates/list.html`**: Add a sticky footer bar showing `Total: €12.50 (8/15 items priced)`
- **`templates/home.html`**: Show list total on each list card
- **Export/Import**: Include `price` field in JSON/CSV export

### Configuration
- Default currency stored in settings (localStorage or DB)
- Currency symbol derived from locale (`i18n/en.json` → `currency.symbol: "€"`)

---

## 2. Multiple Units (Medium Impact, Medium Effort)

### Goal
Replace the numeric-only quantity stepper with a unit-aware input: `2 kg`, `1 L`, `3 pcs`.

### Database Changes
```sql
ALTER TABLE items ADD COLUMN unit TEXT DEFAULT '';
```

### Predefined Units
```json
["pcs", "kg", "g", "L", "mL", "pack", "bag", "bunch", "can", "bottle", "dozen", "slice", "box"]
```

### Backend Changes
- **`db/queries.go`**: Add `unit` field to Item struct, create/update queries
- **`handlers/items.go`**: Accept `unit` in item creation/update

### Frontend Changes
- **Quantity stepper redesign**: When user taps the quantity, show a popover with:
  - Number input (current stepper)
  - Unit dropdown (the predefined list above)
- Display changes: `2` → `2 kg`, `1` → `1 L`, `3` (no unit) → `3×`
- The unit dropdown uses an Alpine.js popover with search filter
- Sync via WebSocket: include `unit` in item update broadcasts

### Migration
- Existing items with `quantity: 2` stay as `2 pcs` (or just `2×` — `unit` defaults to empty string for backward compat)

---

## 3. Shared List Notifications (High Impact, High Effort)

### Goal
Push a notification to the other user's phone when items are added, checked off, or the list is modified.

### Architecture Options

#### Option A: Web Push (Recommended)
- Uses the WPA Push API + a VAPID key pair
- Each browser subscribes to push, stores the subscription in DB
- Server sends push via `web-push` (Go library: `github.com/SherClockHolmes/webpush-go`)
- No external dependencies — works with your existing self-hosted setup

#### Option B: SSE + Polling Fallback
- Simpler: add a server-sent events endpoint per list
- Browser keeps a persistent connection; shows a browser notification
- Falls back to periodic polling if SSE fails
- Less reliable on mobile (killed in background)

### Implementation (Option A — Web Push)

#### Backend
- **`db/db.go`**: New table `push_subscriptions (id, list_id, endpoint, p256dh, auth, created_at)`
- **`handlers/push.go`**: New file with endpoints:
  - `POST /push/subscribe` — stores a browser push subscription for a list
  - `POST /push/unsubscribe` — removes subscription
- **`handlers/ws.go`**: In `BroadcastUpdate()`, after sending WS, also trigger push notifications for offline clients
- **`handlers/push.go`**: `sendPushNotification(subscription, payload)` — sends encrypted push via VAPID
- **VAPID keys**: Generate once, store as env vars or in DB

#### Frontend
- **`templates/layout.html`**: Register service worker for push, request notification permission
- **`templates/list.html`**: "Enable notifications" toggle per list
- **`static/app.js`**: Handle push subscription registration and display incoming notifications

#### Privacy
- Push subscriptions are per-list, per-device
- Only sends: "{user} added {item}" / "{user} checked off {item}" / "{user} removed {item}"
- Requires explicit opt-in via browser permission prompt

---

## 4. Smart Suggestions (Enhancement, Low Effort)

### Goal
Enhance the existing item history autocomplete to show suggestions faster and be more relevant.

### Current State
- `GetItemSuggestions` in `db/queries.go:1293` fetches 200 history items, scores them with Levenshtein distance in Go
- Only available when creating items

### Improvements

#### 4a. Faster Suggestions
- Replace in-memory Levenshtein with SQL `LIKE` prefix matching for the first pass
- Only compute Levenshtein for the top 20 SQL-filtered results
- Add a check frequency counter: items added more often appear first

#### 4b. Context-Aware Suggestions
- When adding an item to "Produce" section, prioritize items previously added to "Produce"
- Use `last_section_id` from `item_history` to pre-filter suggestions by current section

#### 4c. Recently Used First
- Sort by `last_used_at DESC` as primary, `usage_count DESC` as secondary
- Show "Recently added" section above "Frequently bought"

#### 4d. Suggestion UI
- Show suggestions dropdown immediately on focus (before typing)
- Group: "Recent" (last 5 unique items) → "Frequent" (top 10) → "Similar" (Levenshtein matches)
- Tap suggestion fills name + unit + section in one step

### Backend Changes
```sql
CREATE INDEX IF NOT EXISTS idx_item_history_last_used ON item_history(last_used_at DESC);
CREATE INDEX IF NOT EXISTS idx_item_history_section ON item_history(last_section_id);
```

---

## 5. Category Presets (Medium Impact, Low Effort)

### Goal
When creating a new list, offer pre-defined section templates so users don't have to manually type "Produce", "Dairy", etc.

### Implementation

#### Database
- No schema changes needed — this uses the existing `templates` table
- Pre-populate templates on first run or via a migration

#### Backend
- **`db/db.go`**: In `runMigrations()`, add a new migration that checks if templates exist. If not, seed:
```go
predefinedTemplates := []struct{
    Name, Icon string
    Sections  []string
}{
    {"Grocery Essentials", "🛒", []string{"Produce", "Dairy", "Meat & Seafood", "Bakery", "Pantry", "Frozen", "Beverages", "Snacks", "Household", "Personal Care"}},
    {"Weekly Meal Prep", "🍳", []string{"Produce", "Proteins", "Grains & Pasta", "Sauces & Spices", "Dairy & Eggs", "Frozen"}},
    {"Quick Shop", "⚡", []string{"Need Now", "Eventually", "Maybe"}},
}
```

- **`handlers/templates.go`**: Add `POST /templates/:id/apply` endpoint that creates sections from template items

#### Frontend
- **`templates/home.html`**: When creating a new list, show a "Start from template" option
- Template selector modal with icons and section previews
- After list creation, sections are pre-populated from the template
- Allow marking system templates as non-deletable

---

## 6. Auto Dark Mode Schedule (Low Impact, Low Effort)

### Goal
Automatically switch between light and dark mode based on time of day, without overriding manual preference.

### Implementation

#### Frontend Only (No Backend Changes)

**`templates/layout.html`** — extend the existing theme initialization:

```javascript
function getThemePreference() {
    const stored = localStorage.getItem('theme');
    if (stored === 'dark' || stored === 'light') return stored;
    // Auto mode: follow system preference
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}
```

Add a new "Auto" option in the settings modal (next to Light/Dark):

- `"auto"` — uses `prefers-color-scheme` media query (already the default)
- `"light"` — always light
- `"dark"` — always dark

Also add a time-based fallback (for browsers that don't support `prefers-color-scheme`):

```javascript
function getTimeBasedTheme() {
    const hour = new Date().getHours();
    // Dark between 8pm and 7am
    return (hour >= 20 || hour < 7) ? 'dark' : 'light';
}
```

#### Settings Modal
- `templates/home.html`: Add radio group in settings:
  - ☀️ Light / 🌙 Dark / 🔄 Auto (follows system/time)
- Store in `localStorage.setItem('theme', 'auto')`

---

## 7. List Sharing via Link (High Impact, High Effort)

### Goal
Generate a shareable link that allows guests (no login) to view and edit a list for a limited time.

### Architecture

#### Database
```sql
CREATE TABLE IF NOT EXISTS share_links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    list_id INTEGER NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    permission TEXT NOT NULL DEFAULT 'edit',  -- 'edit' or 'view'
    expires_at INTEGER,                         -- NULL = never expires
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_share_links_token ON share_links(token);
```

#### Backend
- **`handlers/share.go`**: New file
  - `POST /lists/:id/share` — creates a share link (generates random token, stores in DB)
  - `DELETE /share/:token` — revokes a share link
  - `GET /share/:token` — renders the list page without auth for the guest
  - Middleware: `ShareAuthMiddleware` — validates token, checks expiry, sets list context
- **`main.go`**: Add share routes outside the auth middleware block:
  ```go
  app.Get("/share/:token", handlers.SharedListView)
  app.Post("/share/:token/items", handlers.SharedCreateItem)
  // etc.
  ```

#### Frontend
- **`templates/home.html`**: "Share" button on each list card → opens modal with:
  - "Can edit" / "Can view" dropdown
  - "7 days" / "30 days" / "Never expires" expiry
  - Generated share link with copy button
  - QR code (using a lightweight JS library like `qrcode.js`)
- **`templates/list.html`**: "Share" button in the header
- **`templates/share.html`**: New template for guest view — simplified list view without settings/import/export
- **WebSocket**: Guest connections restricted to the shared list only

#### Security
- Tokens are 32-byte hex random (same as sessions)
- Rate-limited (prevent abuse)
- Optional: IP-based rate limiting for share links
- Share link view doesn't expose other lists

---

## 8. Offline-First Indicator (Low Impact, Low Effort)

### Goal
Show a small visual indicator when the app is operating from the service worker cache (offline or stale data).

### Implementation

#### Frontend Only

**`templates/layout.html`** — add an offline indicator bar at the top:

```html
<div x-data="{ online: navigator.onLine }" 
     x-init="window.addEventListener('online', () => online = true); 
             window.addEventListener('offline', () => online = false)"
     x-show="!online" 
     x-transition
     class="fixed top-0 left-0 right-0 bg-amber-500 text-white text-center text-sm py-1 z-50">
    📡 Offline — changes will sync when reconnected
</div>
```

- Green dot (🟢) or Wi-Fi icon in header when online
- Amber bar at top when offline
- The existing `sw.js` and `offline-storage.js` already handle local writes and queue them
- Add a small pending count badge: "3 changes pending" shown in the offline bar

#### Status Detection
- Use `navigator.onLine` for initial state
- Listen to `online`/`offline` events for state changes
- Use the service worker's `isOnline` flag (already exists in `offline-storage.js`)

---

## 9. Recipe Mode (High Impact, High Effort)

### Goal
Paste a recipe (text or URL), and auto-extract ingredients into a shopping list with sections.

### Architecture

#### Option A: Local Parsing (Self-Contained, Recommended)
- Frontend-only parsing using regex and NLP-like extraction
- Common patterns: `"2 cups flour"` → `{quantity: 2, unit: cups, name: flour}`
- Ingredient dictionary for categorization (flour → Bakery, chicken → Meat)
- No external API calls — fully offline

#### Option B: External API (Better Accuracy)
- Call an LLM or recipe API to parse ingredients
- Requires API key, network dependency, adds latency

### Implementation (Option A)

#### Frontend

- **`templates/home.html`**: "Recipe → List" button in the header
- Opens a modal with a large textarea: "Paste your recipe here"
- On paste, client-side parser:
  1. Split text into lines
  2. Match each line against ingredient patterns: `(\d+[\d/]*\s*)?(cups?|tbsp|tsp|lbs?|oz|g|kg|ml|L|pieces?|cloves?|slices?|cans?|bags?|bunches?)?\s+(.+)`
  3. Map ingredient names to section categories using a dictionary
  4. Display parsed items in a preview with checkboxes
  5. User can edit/remove items before creating the list
- Click "Create List" → POST to `/lists` with `{name: "Recipe: {title}", sections: [...]}`

#### Ingredient Dictionary
- Static JSON file: `static/ingredient-categories.json`
- Structure: `{ "flour": "Bakery", "milk": "Dairy", "chicken": "Meat & Seafood", ... }`
- ~200 common ingredients pre-mapped
- Auto-adds new items to "Other" section, user can move them

#### Backend
- No new endpoints needed — uses existing `CreateList` + `CreateSection` + `CreateItem`
- Could add `POST /lists/from-recipe` as a convenience endpoint that accepts structured recipe data

---

## Implementation Priority Order

| # | Feature | Impact | Effort | Recommended Sprint |
|---|---------|--------|--------|---------------------|
| 1 | Offline Indicator | Low | Low | Sprint 1 (quick win) |
| 2 | Auto Dark Mode | Low | Low | Sprint 1 (quick win) |
| 3 | Category Presets | Medium | Low | Sprint 1 |
| 4 | Smart Suggestions | Medium | Low | Sprint 2 |
| 5 | Multiple Units | Medium | Medium | Sprint 2 |
| 6 | Price Tracking | High | Medium | Sprint 3 |
| 7 | Recipe Mode | High | High | Sprint 4 |
| 8 | List Sharing via Link | High | High | Sprint 5 |
| 9 | Push Notifications | High | High | Sprint 6 |

---

*Last updated: 2026-04-22*
*Based on code review of Bentomo Shopping (fork of Bolex80/Shopping, originally PanSalut/Koffan v2.9.0)*