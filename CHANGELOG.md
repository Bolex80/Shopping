# Changelog — Bentomo Shopping

> All changes made on top of the upstream fork point **Koffan v2.9.0** (`5d54d84`).
> Upstream: `github.com/PanSalut/Koffan` · Fork: `github.com/Bolex80/Shopping`.

---

## Fork changes (v2.9.0 → current)

### Functional features

#### Auto-archive scheduler (new)
Automatically archives completed items from fully-completed lists when a new week or month starts.

- `handlers/autoarchive.go` — **new file**. Background goroutine, checks every 5 min + on startup, detects week/month rollover, archives completed items, broadcasts via WebSocket.
- `db/db.go` — new `auto_archive_state` table + `migrateAutoArchiveState()`.
- `db/queries.go` — `ArchiveCompletedItems()`, `GetAutoArchiveState()`, `SetAutoArchiveState()`, `GetFullyCompletedListIDs()`.
- `main.go` — `StartAutoArchiveScheduler()` call + route `POST /lists/:id/archive-completed`.
- `handlers/items.go` — `ArchiveCompletedItems` handler (manual "Archive bought items" button).
- `static/app.js` — `archiveCompletedItems()` + WS handlers for `completed_items_archived` / `auto_archive_completed`.
- `i18n/en.json`, `i18n/es.json` — archive strings.

#### WebSocket broadcast hardening (bug fix)
- `handlers/ws.go` — snapshot iteration + dead-client cleanup (was iterating the live map while writing).

#### SQLite concurrency fixes (bug fix)
- `db/db.go` — connection pool `1 → 5` (WAL mode).
- `db/queries.go` — `sortOrderMu` mutex on all 6 move/reorder operations (list/section/item up/down).

#### Auth security hardening (security fix)
- `handlers/auth.go` — constant-time password compare, proper `sql.ErrNoRows` handling, `generateSessionID()` returns error instead of `log.Fatal`.
- `api/middleware.go` — constant-time API token compare.

#### Export/import robustness (bug fix)
- `handlers/export.go` — `UnmarshalJSON` handles string-vs-int quantity (backward compat with old exports).
- `handlers/import.go` — accepts both `bentomo` and `koffan` app names.

#### Version check removal (deliberate)
- `handlers/version.go` — removed the GitHub API call that checked upstream Koffan for updates (now returns "unknown").

#### Dockerfile (deployment)
- Port `80 → 3001`, healthcheck URL, image labels → `Bolex80/Shopping`.

### Branding (cosmetic)

- All logos/favicons/icons (7 new PNGs), `apply-bentomo-theme.sh`, README, `FEATURE-ROADMAP.md`.
- `static/sw.js` — cache names `koffan-` → `bentomo-`, offline page text, asset list.
- `static/offline-storage.js` — IndexedDB name `koffan-offline` → `bentomo-offline`.
- `i18n/*.json` — "Koffan" → "Bentomo" strings.
- `templates/*` — logo/name/archive-button markup.

---

## Merge risk vs. upstream (v2.10.0 → v2.13.0)

| Fork change | Upstream also touched? | Risk |
|---|---|---|
| Auto-archive (new files/funcs) | No | 🟢 Safe |
| `sortOrderMu` mutexes | `queries.go` (DB indexes) | 🟡 Low |
| WS broadcast fix | `ws.go` (webhooks) | 🟡 Low |
| Auth hardening | `auth.go` | 🟡 Low |
| Export/import | `export.go`/`import.go` (stability) | 🟡 Medium |
| Dockerfile port 3001 | port → 8080 (v2.10.0) | 🔴 Conflict |
| Branding (templates/sw.js/app.js/i18n) | UI scale, offline fixes, Italian | 🔴 Conflict |

**Merge strategy (decided 2026-09-03):** cherry-pick only the safe upstream features
(webhooks, DB indexes, offline fixes) onto the fork — do **not** full-sync, to avoid
re-applying branding over upstream's newer UI code.

---

## Upstream features NOT in this fork (post-v2.9.0)

| Version | Feature |
|---|---|
| v2.10.0 | Mobile sheet viewport fix; default port → 8080 + parametrized healthcheck |
| v2.11.0 | Italian locale; quantity selector in add-item form |
| v2.12.0 | UI scale selector (accessibility) + logo shrink |
| v2.12.1 | Offline add + cold-start fixes; clear SW caches on logout |
| v2.12.2 | Compress icons, version vendor JS, DB indexes, wrap long item names |
| v2.13.0 | Outbound item webhooks + import/runtime stability fixes |
