#!/bin/bash
set -euo pipefail

APP_CONTAINER="udom-cloud-deployment-app-1"
THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../customizations/theme" && pwd)"
CSS_FILE="$THEME_DIR/udom_login_theme.css"

if ! docker ps --format '{{.Names}}' | grep -Fxq "$APP_CONTAINER"; then
  echo "Nextcloud app container '$APP_CONTAINER' is not running. Start the stack first."
  exit 1
fi

docker exec -u 33 "$APP_CONTAINER" php occ app:install --force --allow-unstable theming_customcss >/dev/null 2>&1 || true
docker exec -u 33 "$APP_CONTAINER" php occ app:enable theming_customcss >/dev/null 2>&1 || true

docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming enabled --value="yes"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming name --value="UDOM Cloud"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming slogan --value="Embracing Knowledge"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming url --value="https://udomcloud.com"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming imprintUrl --value="https://www.udom.ac.tz/#"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming privacyUrl --value="https://www.udom.ac.tz/site/contact"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming background_color --value="#F9F9F9"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming primary_color --value="#0764C1"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming_customcss enabled --value="yes"

docker cp "$CSS_FILE" "$APP_CONTAINER:/tmp/udom_login_theme.css"
docker exec -u 33 "$APP_CONTAINER" bash -lc 'php occ config:app:set theming_customcss customcss --value="$(cat /tmp/udom_login_theme.css)"'

theme_images_dir="$(docker exec -u 33 "$APP_CONTAINER" bash -lc "find /var/www/html/data -path '*/theming/global/images' -type d 2>/dev/null | head -n 1")"
if [ -n "$theme_images_dir" ]; then
  for asset in logo favicon logoheader; do
    if [ -f "$THEME_DIR/${asset}.png" ]; then
      docker cp "$THEME_DIR/${asset}.png" "$APP_CONTAINER:/tmp/${asset}.png"
      docker exec -u 33 "$APP_CONTAINER" bash -lc "cp /tmp/${asset}.png '$theme_images_dir/${asset}'"
    fi
  done
fi

docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming logoMime --value="image/png"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming faviconMime --value="image/png"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming logoheaderMime --value="image/png"
docker exec -u 33 "$APP_CONTAINER" php occ config:app:set theming_customcss cachebuster --value="$(date +%s)"

echo "UDOM theming has been applied to the Nextcloud instance."
