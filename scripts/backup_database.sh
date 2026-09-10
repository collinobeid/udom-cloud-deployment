#!/bin/bash

set -e

BACKUP_DIR="/var/backups/udom-cloud"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/nextcloud_db_$DATE.sql.gz"

echo "=========================================="
echo "UDOM CLOUD - DATABASE BACKUP"
echo "=========================================="

mkdir -p "$BACKUP_DIR"

if ! docker compose ps db --status running | grep -q "db"; then
    echo "ERROR: MariaDB service is not running."
    exit 1
fi

echo "Creating MariaDB backup..."

docker compose exec -T db \
    mariadb-dump \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    --single-transaction \
    --routines \
    --triggers \
    "$MYSQL_DATABASE" \
    | gzip > "$BACKUP_FILE"

if [ ! -s "$BACKUP_FILE" ]; then
    echo "ERROR: Backup was not created correctly."
    rm -f "$BACKUP_FILE"
    exit 1
fi

echo ""
echo "Database backup completed successfully."
echo "File: $BACKUP_FILE"

ls -lh "$BACKUP_FILE"