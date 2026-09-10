#!/bin/bash

set -e

BACKUP_DIR="/var/backups/udom-cloud"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/nextcloud_data_$DATE.tar.gz"

echo "=========================================="
echo "UDOM CLOUD - NEXTCLOUD DATA BACKUP"
echo "=========================================="

mkdir -p "$BACKUP_DIR"

echo "Creating Nextcloud data archive..."

docker run --rm \
    -v udom-cloud-deployment_nextcloud_data:/source:ro \
    -v "$BACKUP_DIR":/backup \
    alpine:latest \
    tar -czf "/backup/nextcloud_data_$DATE.tar.gz" -C /source .

if [ ! -s "$BACKUP_FILE" ]; then
    echo "ERROR: Nextcloud data backup failed."
    exit 1
fi

echo ""
echo "Nextcloud data backup completed."

ls -lh "$BACKUP_FILE"