#!/bin/bash

set -e
set -o pipefail

BACKUP_DIR="./backups/nextcloud"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/nextcloud_data_$DATE.tar.gz"

VOLUME_NAME="udom-cloud-deployment_nextcloud_data"
HOST_BACKUP_DIR="/c/Users/User/udom-cloud-deployment/backups/nextcloud"

echo "=========================================="
echo "UDOM CLOUD - NEXTCLOUD DATA BACKUP"
echo "=========================================="

mkdir -p "$BACKUP_DIR"

echo "Checking Nextcloud data volume..."

if ! docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1; then
    echo "ERROR: Docker volume '$VOLUME_NAME' does not exist."
    exit 1
fi

echo "Creating Nextcloud data archive..."
echo "Volume: $VOLUME_NAME"

MSYS_NO_PATHCONV=1 docker run --rm \
    -v "$VOLUME_NAME:/source:ro" \
    -v "C:/Users/User/udom-cloud-deployment/backups/nextcloud:/backup" \
    alpine:latest \
    tar -czf "/backup/nextcloud_data_$DATE.tar.gz" -C /source .

if [ ! -s "$BACKUP_FILE" ]; then
    echo "ERROR: Nextcloud data backup failed."
    rm -f "$BACKUP_FILE"
    exit 1
fi

echo ""
echo "Nextcloud data backup completed successfully."
echo "File: $BACKUP_FILE"

ls -lh "$BACKUP_FILE"