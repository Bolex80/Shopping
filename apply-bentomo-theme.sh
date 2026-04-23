#!/usr/bin/env bash
# =============================================================================
# Bentomo Theme Patch Script
# Run this AFTER merging or pulling upstream Koffan changes.
# It reapplies all Bentomo branding, colors, and logo changes automatically.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[Bentomo Patch] Starting theme patch..."

# ---------------------------------------------------------------------------
# 1. TAILWIND COLOR CLASSES: pink → blue (template HTML files)
# ---------------------------------------------------------------------------
echo "[Bentomo Patch] Step 1: Replacing pink with blue color classes..."

find templates -name "*.html" -type f | while read -r file; do
    sed -i \
        -e 's/pink-50/blue-50/g' \
        -e 's/pink-100/blue-100/g' \
        -e 's/pink-200/blue-200/g' \
        -e 's/pink-300/blue-300/g' \
        -e 's/pink-400/blue-400/g' \
        -e 's/pink-500/blue-500/g' \
        -e 's/pink-600/blue-600/g' \
        -e 's/pink-700/blue-700/g' \
        -e 's/pink-800/blue-800/g' \
        -e 's/pink-900\/20/blue-900\/20/g' \
        -e 's/pink-900\/30/blue-900\/30/g' \
        -e 's/pink-900\/50/blue-900\/50/g' \
        -e 's/pink-900\/70/blue-900\/70/g' \
        -e 's/pink-900/blue-900/g' \
        "$file"
done

# Revert accidental double-prefix fixes from overlapping replacements
find templates -name "*.html" -type f | while read -r file; do
    sed -i \
        -e 's/blue-blue-/blue-blue-/g' \
        "$file" 2>/dev/null || true
done

# ---------------------------------------------------------------------------
# 2. INLINE CSS HEX COLORS (layout.html, login.html)
# ---------------------------------------------------------------------------
echo "[Bentomo Patch] Step 2: Replacing inline hex colors..."

for file in templates/layout.html templates/login.html; do
    if [[ -f "$file" ]]; then
        sed -i \
            -e 's/#f9a8d4/#2563eb/g' \
            -e 's/#f472b6/#3b82f6/g' \
            -e 's/#ec4899/#2563eb/g' \
            -e 's/#fce7f3/#dbeafe/g' \
            -e 's/#fdf2f8/#eff6ff/g' \
            -e 's/#db2777/#1d4ed8/g' \
            -e 's/content: \x27#1c1917\x27/content: \x27#1e293b\x27/g' \
            "$file"
    fi
done

# ---------------------------------------------------------------------------
# 3. FAVICON & PWA REFERENCES (layout.html) — ALL POINT TO bentomo-logo-smaller.png
# ---------------------------------------------------------------------------
echo "[Bentomo Patch] Step 3: Updating favicon references..."

if [[ -f "templates/layout.html" ]]; then
    sed -i \
        -e 's|<link rel="icon" .*|<!-- FAVICON -->\n    <link rel="icon" type="image/png" href="/static/bentomo-logo-smaller.png" sizes="96x96">\n    <link rel="icon" type="image/png" href="/static/bentomo-logo-smaller.png" sizes="32x32">\n    <link rel="apple-touch-icon" href="/static/bentomo-logo-smaller.png">|g' \
        templates/layout.html
    # Fix-up: remove duplicate favicon lines and old refs
    sed -i '/href="\/static\/favicon-32.png"/d' templates/layout.html
    sed -i '/href="\/static\/favicon-96.png"/d' templates/layout.html
    sed -i '/href="\/static\/icon-192.png"/d' templates/layout.html
    sed -i '/href="\/static\/apple-touch-icon.png"/d' templates/layout.html
    sed -i '/href="\/static\/bentomo-logo.png"/d' templates/layout.html
fi

# ---------------------------------------------------------------------------
# 4. MANIFEST.JSON COLORS
# ---------------------------------------------------------------------------
echo "[Bentomo Patch] Step 4: Updating manifest.json..."

if [[ -f "static/manifest.json" ]]; then
    sed -i \
        -e 's/"theme_color": "#f9a8d4"/"theme_color": "#2563eb"/g' \
        -e 's/"short_name": "Koffan"/"short_name": "Bentomo"/g' \
        -e 's/"name": "Koffan Shopping List"/"name": "Bentomo Shopping List"/g' \
        -e 's/"description": "Shopping list management app"/"description": "Bentomo shopping list management app"/g' \
        static/manifest.json
fi

# ---------------------------------------------------------------------------
# 5. PAGE TITLES & BRANDING STRINGS
# ---------------------------------------------------------------------------
echo "[Bentomo Patch] Step 5: Updating page titles and text branding..."

sed -i 's/>Koffan Shopping List</>Bentomo Shopping List</g' templates/layout.html 2>/dev/null || true
sed -i 's/Login - Koffan/Login - Bentomo/g' templates/login.html 2>/dev/null || true
sed -i 's/alt="Koffan Logo"/alt="Bentomo Logo"/g' templates/*.html templates/**/*.html 2>/dev/null || true
sed -i '/Welcome to Koffan/d' templates/*.html templates/**/*.html 2>/dev/null || true

# Footer in home.html (sponsor/bug report)
sed -i 's|https://github.com/sponsors/PanSalut|#|g' templates/home.html 2>/dev/null || true
sed -i 's|https://github.com/PanSalut/Koffan|#|g' templates/home.html 2>/dev/null || true
sed -i 's|>Koffan <|>Bentomo <|g' templates/home.html 2>/dev/null || true

# ---------------------------------------------------------------------------
# 6. MAIN APP LOGO (header / login / list pages)
# ---------------------------------------------------------------------------
echo "[Bentomo Patch] Step 6: Updating main app logo to Bentomo family..."

sed -i 's|src="/static/koffan-logo.webp"|src="/static/Bentomo-shopping-family-hugotaller.png"|g' templates/*.html templates/**/*.html 2>/dev/null || true
sed -i 's|src="/static/bentomo-logo.png"|src="/static/Bentomo-shopping-family-hugotaller.png"|g' templates/*.html templates/**/*.html 2>/dev/null || true
sed -i 's|src="/static/Bentomo-Shopping-family-black-TR.png"|src="/static/Bentomo-shopping-family-hugotaller.png"|g' templates/*.html templates/**/*.html 2>/dev/null || true

# ---------------------------------------------------------------------------
# 7. SERVICE WORKER & OFFLINE STORAGE REBRANDING
# ---------------------------------------------------------------------------
echo "[Bentomo Patch] Step 7: Updating SW and offline storage names..."

sed -i 's/koffan-offline/bentomo-offline/g' static/offline-storage.js 2>/dev/null || true
sed -i "s/'koffan-/'bentomo-/g" static/sw.js 2>/dev/null || true
sed -i 's|/static/koffan-logo.webp|/static/bentomo-logo.png|g' static/sw.js 2>/dev/null || true
sed -i 's/Koffan Offline/Bentomo Offline/g' static/sw.js 2>/dev/null || true
sed -i 's/Koffan Service Worker/Bentomo Service Worker/g' static/sw.js 2>/dev/null || true

# ---------------------------------------------------------------------------
# 8. GOLANG HANDLERS
# ---------------------------------------------------------------------------
echo "[Bentomo Patch] Step 8: Updating Go handler exports..."

# Fix SQLite connection pool to avoid deadlock during import (transaction + query)
sed -i 's/DB.SetMaxOpenConns(1)/DB.SetMaxOpenConns(5)/g' db/db.go 2>/dev/null || true

sed -i 's/koffan-export-/bentomo-export-/g' handlers/export.go 2>/dev/null || true
sed -i 's/koffan-export/bentomo-export/g' handlers/export.go 2>/dev/null || true
sed -i 's/koffan-export/bentomo-export/g' handlers/export.go 2>/dev/null || true
sed -i 's|"koffan".*$|"bentomo",|g' handlers/export.go 2>/dev/null || true || true

# Import compatibility — keep BOTH app names valid
sed -i 's/exportData.App != "koffan".*&& exportData.App != ""/exportData.App != "bentomo" \u0026\u0026 exportData.App != "koffan" \u0026\u0026 exportData.App != ""/g' handlers/import.go 2>/dev/null || true
sed -i 's/This file was not exported from Koffan/This file was not exported from Bentomo/g' handlers/import.go 2>/dev/null || true

# ---------------------------------------------------------------------------
# 9. I18N TRANSLATIONS
# ---------------------------------------------------------------------------
echo "[Bentomo Patch] Step 9: Updating English i18n strings..."

sed -i 's/Koffan Shopping List/Bentomo Shopping List/g' i18n/en.json 2>/dev/null || true
sed -i 's/Login - Koffan/Login - Bentomo/g' i18n/en.json 2>/dev/null || true
sed -i 's/Welcome to Koffan/Welcome to Bentomo/g' i18n/en.json 2>/dev/null || true

# ---------------------------------------------------------------------------
# 10. DOCKER / BUILD FILES
# ---------------------------------------------------------------------------
echo "[Bentomo Patch] Step 10: Updating Docker metadata..."

sed -i 's|https://github.com/PanSalut/Koffan|https://github.com/Bolex80/Shopping|g' Dockerfile 2>/dev/null || true
sed -i 's/Koffan/Bentomo/g' Dockerfile 2>/dev/null || true

# ---------------------------------------------------------------------------
# 11. GO MODULE / VERSION CHECKER
# ---------------------------------------------------------------------------
echo "[Bentomo Patch] Step 11: Neutralizing version checker..."

if grep -q 'githubTagsURL' handlers/version.go 2>/dev/null; then
    cat > handlers/version.go << 'GOLANG_EOF'
package handlers

import (
	"strings"
	"sync"
	"time"

	"github.com/gofiber/fiber/v2"
)

var AppVersion = "dev"

const versionCacheTTL = 1 * time.Hour

var (
	cachedVersion     string
	cachedVersionTime time.Time
	versionMutex      sync.RWMutex
)

type versionResponse struct {
	Current         string `json:"current"`
	Latest          string `json:"latest"`
	UpdateAvailable bool   `json:"update_available"`
}

func GetVersion(c *fiber.Ctx) error {
	return c.JSON(versionResponse{
		Current:         AppVersion,
		Latest:          "unknown",
		UpdateAvailable: false,
	})
}
GOLANG_EOF
    echo "[Bentomo Patch]   → Replaced version.go with neutral implementation"
fi

# ---------------------------------------------------------------------------
echo "[Bentomo Patch] Done! All branding changes reapplied."
echo "[Bentomo Patch] Next: rebuild the Docker image and restart the container."
