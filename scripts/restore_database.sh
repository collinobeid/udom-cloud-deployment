#!/bin/bash

set -e
set -o pipefail

if [ -z "$1" ]; then
    echo "Usage:"
    echo "./scripts/restore_database.sh /path/to/backup.sql.gz [database_name]"
    exit 1
fi

BACKUP_FILE="$1"
TARGET_DATABASE="${2:-$MYSQL_DATABASE}"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file does not exist."
    exit 1
fi

if [ -z "$TARGET_DATABASE" ]; then
    echo "ERROR: Target database is not specified."
    exit 1
fi

echo "=========================================="
echo "UDOM CLOUD DATABASE RESTORE"
echo "=========================================="

echo ""
echo "Backup file:"
echo "$BACKUP_FILE"

echo ""
echo "Target database:"
echo "$TARGET_DATABASE"

echo ""
echo "WARNING!"
echo "This operation will restore the selected database."
echo ""

read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo ""
echo "Restoring database..."

gunzip -c "$BACKUP_FILE" | \
docker compose exec -T db sh -c \
'mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$1"' \
-- "$TARGET_DATABASE"

echo ""
echo "Database restore completed successfully."