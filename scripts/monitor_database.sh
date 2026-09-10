#!/bin/bash

set -e

echo "=========================================="
echo "UDOM CLOUD DATABASE MONITOR"
echo "=========================================="

echo ""
echo "Checking MariaDB service..."

if docker compose ps db --status running | grep -q "db"; then
    echo "MariaDB container: RUNNING"
else
    echo "ERROR: MariaDB container is NOT running."
    exit 1
fi

echo ""
echo "Testing MariaDB connection..."

if docker compose exec -T db \
    mariadb-admin \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    ping --silent; then

    echo "MariaDB connection: OK"
else
    echo "ERROR: MariaDB connection failed."
    exit 1
fi

echo ""
echo "Database monitoring completed successfully."