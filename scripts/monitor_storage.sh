#!/bin/bash

set -e

THRESHOLD=80

echo "=========================================="
echo "UDOM CLOUD STORAGE MONITOR"
echo "=========================================="

echo ""
echo "Disk usage:"
df -h /

echo ""
echo "Docker volumes:"
docker volume ls

echo ""
echo "Docker disk usage:"
docker system df

USAGE=$(df / | awk 'NR==2 {print int($5)}')

echo ""
echo "Root filesystem usage: ${USAGE}%"

if [ "$USAGE" -ge "$THRESHOLD" ]; then
    echo "WARNING: Disk usage is above ${THRESHOLD}%."
    exit 1
else
    echo "Storage status: OK"
fi