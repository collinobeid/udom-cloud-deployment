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

# Find the filesystem usage percentage regardless of spaces
# in the filesystem/mount path (important for Git Bash on Windows).
USAGE=$(df -P / | awk '{
    for (i = 1; i <= NF; i++) {
        if ($i ~ /^[0-9]+%$/) {
            gsub("%", "", $i)
            print $i
            exit
        }
    }
}')

# Validate the value
if ! [[ "$USAGE" =~ ^[0-9]+$ ]]; then
    echo ""
    echo "ERROR: Unable to determine root filesystem usage."
    exit 1
fi

echo ""
echo "Root filesystem usage: ${USAGE}%"

if [ "$USAGE" -ge "$THRESHOLD" ]; then
    echo "WARNING: Disk usage is above ${THRESHOLD}%."
    exit 1
else
    echo "Storage status: OK"
fi