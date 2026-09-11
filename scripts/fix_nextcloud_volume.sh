#!/usr/bin/env bash
set -euo pipefail

# fix_nextcloud_volume.sh
# Usage: run from the repository root (where docker-compose.yml lives)
# This script will:
# - stop the compose stack
# - ensure the nextcloud_data named volume exists
# - if /var/www/html in the volume lacks index.php, populate the volume from the nextcloud image
# - chown the files to www-data:www-data
# - restart compose and show verification

COMPOSE_PROJECT_DIR="$(pwd)"
IMAGE_NAME="nextcloud:34.0.3-apache"

# Default volume name used by this compose project
VOLUME_NAME="udom-cloud-deployment_nextcloud_data"

echo "Working directory: $COMPOSE_PROJECT_DIR"
echo "Target nextcloud volume: $VOLUME_NAME"
echo "Nextcloud image used to populate: $IMAGE_NAME"
echo

# Ensure .env exists
if [ ! -f .env ]; then
  echo "ERROR: .env not found in repo root. Please create .env from .env.example before running this script."
  echo "  cp .env.example .env ; edit .env"
  exit 1
fi

# Stop compose stack (do not remove volumes automatically here)
echo "Stopping compose stack..."
docker compose down || true

# Create volume if missing
if ! docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1; then
  echo "Creating volume $VOLUME_NAME ..."
  docker volume create "$VOLUME_NAME"
fi

# Quick check whether index.php already exists inside volume
echo "Checking for index.php inside the volume..."
has_index=$(docker run --rm -v "$VOLUME_NAME":/data busybox sh -c 'test -f /data/index.php && echo yes || echo no')
echo "index.php present in volume? -> $has_index"

if [ "$has_index" = "yes" ]; then
  echo "Volume already contains index.php — skipping populate step."
else
  echo "Populating volume from image ($IMAGE_NAME) into volume $VOLUME_NAME ..."
  # Use tar stream: produce tar from image /var/www/html and extract into volume
  docker run --rm --entrypoint tar "$IMAGE_NAME" -cC /var/www/html -f - . \
    | docker run --rm -i -v "$VOLUME_NAME":/data busybox tar -xC /data
  echo "Files copied into volume."
fi

# Fix ownership to www-data:www-data using the nextcloud image (ensures same UID/GID)
echo "Fixing ownership to www-data:www-data in volume..."
docker run --rm -v "$VOLUME_NAME":/var/www/html "$IMAGE_NAME" chown -R www-data:www-data /var/www/html || true

# Start the stack again
echo "Starting compose stack..."
docker compose up -d --build

# Wait a short time for containers to initialize
echo "Waiting 8 seconds for containers to come up..."
sleep 8

# Show brief verification
echo "=== Compose ps ==="
docker compose ps

echo
echo "=== App logs (tail 100) ==="
docker compose logs --tail=100 app || true

echo
echo "=== Check index.php inside volume now ==="
docker run --rm -v "$VOLUME_NAME":/data busybox sh -c 'ls -la /data | sed -n "1,120p"'
echo

echo "If index.php is present and app logs show normal startup, open http://localhost:8080 and hard-refresh (Ctrl+F5)."
echo "If problems persist, collect these outputs and share them:" 
echo "  docker compose ps"
echo "  docker compose logs --tail=200 app"
echo "  docker run --rm -v $VOLUME_NAME:/data busybox sh -c 'ls -la /data | sed -n "1,200p"; stat -c "%a %U:%G %n" /data || true'"
