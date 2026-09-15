#!/bin/bash
set -e

echo '======================================'
echo 'Resolving Nextcloud Admin Warnings'
echo '======================================'

echo 'Phase 1: Fixing AppAPI Connection (HaRP Daemon)...'
# Nextcloud's SSRF protection blocks local IPs/hostnames by default.
# We must allow local remote servers so Nextcloud can communicate with the appapi-harp container.
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:system:set allow_local_remote_servers --value=true --type=bool

echo ''
echo 'Phase 2: Fixing Basic Configurations...'
# Set default phone region to Tanzania (TZ)
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:system:set default_phone_region --value='TZ'

# Set maintenance window to 2 AM UTC (low usage time)
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:system:set maintenance_window_start --value=2 --type=integer

# Set server ID (removes the server identifier warning)
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:system:set server_id --value='udomcloud_01'

echo ''
echo 'Cleaning up inactive LDAP configurations...'
# Delete the broken/inactive mock configurations (s01, s02)
docker exec -u 33 udom-cloud-deployment-app-1 php occ ldap:delete-config s01 || true
docker exec -u 33 udom-cloud-deployment-app-1 php occ ldap:delete-config s02 || true

echo ''
echo 'Running Mimetype Migrations (This might take a minute)...'
docker exec -u 33 udom-cloud-deployment-app-1 php occ maintenance:repair --include-expensive

echo ''
echo '======================================'
echo 'Phase 1 & 2 Fixes Applied Successfully!'
echo '======================================'
echo 'Go back to your Nextcloud Admin Overview page and refresh it.'
echo 'Most of the errors should now be completely gone!'
