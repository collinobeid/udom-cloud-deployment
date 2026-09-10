#!/usr/bin/env bash
set -euo pipefail

# apply_udom_theming.sh
# Idempotent script to apply UDOM branding from repo into a running Nextcloud container.
# Usage: run from project root or anywhere; requires Docker & the Nextcloud app container running.

APP_CONTAINER="udom-cloud-deployment-app-1"
THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../customizations/theme" && pwd)"
CSS_FILE="$THEME_DIR/udom_login_theme.css"

# Theme metadata (edit here if you want to change defaults)
THEME_NAME="UDOM Cloud"
THEME_SLOGAN="Embracing Knowledge"
THEME_URL="https://udomcloud.com"
THEME_IMPRINT="https://www.udom.ac.tz/#"
THEME_PRIVACY="https://www.udom.ac.tz/site/contact"
THEME_BACKGROUND="#F9F9F9"
THEME_PRIMARY="#0764C1"

# Ensure container exists
if ! docker ps --format '{{.Names}}' | grep -Fxq "$APP_CONTAINER"; then
  echo "ERROR: Nextcloud app container '$APP_CONTAINER' is not running. Start the stack first (docker compose up -d)."
  exit 1
fi

echo "Installing/enabling theming_customcss app (if missing)..."
docker exec -u 33 "$APP_CONTAINER" php occ app:install --force --allow-unstable theming_customcss >/dev/null 2>&1 || true
docker exec -u 33 "$APP_CONTAINER" php occ app:enable theming_customcss >/dev/null 2>&1 || true

echo "Setting theming metadata..."
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming enabled --value="yes"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming name --value="$THEME_NAME"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming slogan --value="$THEME_SLOGAN"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming url --value="$THEME_URL"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming imprintUrl --value="$THEME_IMPRINT"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming privacyUrl --value="$THEME_PRIVACY"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming background_color --value="$THEME_BACKGROUND"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming primary_color --value="$THEME_PRIMARY"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming_customcss enabled --value="yes"

# Apply CSS
if [ -f "$CSS_FILE" ]; then
  echo "Copying CSS file into container and applying to DB..."
  docker cp "$CSS_FILE" "$APP_CONTAINER:/tmp/udom_login_theme.css"
  # Use bash -lc so the container can read the file and pipe it into occ
  docker exec -u 33 "$APP_CONTAINER" bash -lc 'php occ config:app:set theming_customcss customcss --value="$(cat /tmp/udom_login_theme.css)"'
else
  echo "Warning: CSS file not found at $CSS_FILE — skipping CSS injection."
fi

# Locate Nextcloud theming images directory inside container
echo "Locating Nextcloud theming images directory..."
THEME_IMAGES_DIR="$(docker exec -u 33 "$APP_CONTAINER" bash -lc "find /var/www/html/data -path '*/theming/global/images' -type d 2>/dev/null | head -n 1")"
if [ -z "$THEME_IMAGES_DIR" ]; then
  echo "Warning: could not find Nextcloud theming images directory. Image copy will be skipped."
else
  echo "Theme images directory: $THEME_IMAGES_DIR"
  # Copy images if present in repo theme dir. Detect extension and use correct MIME type.
  for name in logo favicon logoheader; do
    for ext in png svg jpg jpeg ico; do
      src="$THEME_DIR/${name}.${ext}"
      if [ -f "$src" ]; then
        echo "Copying $src -> container:/tmp/${name}.${ext}"
        docker cp "$src" "$APP_CONTAINER:/tmp/${name}.${ext}"
        # Move into the data theming dir inside container (overwrite existing)
        docker exec -u 33 "$APP_CONTAINER" bash -lc "cp /tmp/${name}.${ext} '${THEME_IMAGES_DIR}/${name}' || true"
        # Set MIME type based on extension
        case "$ext" in
          png) mime="image/png" ;;
          svg) mime="image/svg+xml" ;;
          jpg|jpeg) mime="image/jpeg" ;;
          ico) mime="image/x-icon" ;;
          *) mime="application/octet-stream" ;;
        esac
        echo "Setting ${name} MIME to $mime"
        docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming ${name}Mime --value="$mime" || true
        break
      fi
    done
  done
fi

# Force cachebuster so clients see changes
echo "Updating cachebuster to force browser refresh..."
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming_customcss cachebuster --value="$(date +%s)" || true

# Optional: reload Apache to ensure files served (best-effort)
echo "Reloading Apache inside container (best-effort)..."
docker exec "$APP_CONTAINER" bash -lc "if command -v apache2ctl >/dev/null 2>&1; then apache2ctl -k graceful || true; fi"

echo "UDOM theming has been applied. Visit the site and hard-refresh (Ctrl+F5) to see the changes." 
