#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage:"
    echo "./scripts/restore_database.sh /path/to/backup.sql.gz"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file does not exist."
    exit 1
fi

echo "=========================================="
echo "UDOM CLOUD DATABASE RESTORE"
echo "=========================================="

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
docker compose exec -T db \
mariadb \
-u root \
-p"${MYSQL_ROOT_PASSWORD}" \
"$MYSQL_DATABASE"

echo ""
echo "Database restore completed."