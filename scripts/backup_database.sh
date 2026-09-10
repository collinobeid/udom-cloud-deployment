#!/bin/bash

set -e
set -o pipefail

BACKUP_DIR="./backups/database"
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

if docker compose exec -T db sh -c \
    'mariadb-dump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --single-transaction --routines --triggers "$MYSQL_DATABASE"' \
    | gzip > "$BACKUP_FILE"; then

    if [ ! -s "$BACKUP_FILE" ]; then
        echo "ERROR: Backup file is empty."
        rm -f "$BACKUP_FILE"
        exit 1
    fi

    echo ""
    echo "Database backup completed successfully."
    echo "File: $BACKUP_FILE"
    ls -lh "$BACKUP_FILE"

else
    echo ""
    echo "ERROR: MariaDB backup failed."
    rm -f "$BACKUP_FILE"
    exit 1
fi