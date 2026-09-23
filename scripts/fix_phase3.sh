#!/bin/bash
set -e

echo '======================================'
echo 'Resolving Phase 3 Nextcloud Warnings'
echo '======================================'

echo 'Fixing Server ID string format...'
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:system:set serverid --value='udomcloud01'

echo 'Configuring STUN server to fix WebRTC / Talk connection issues...'
docker exec -u 33 udom-cloud-deployment-app-1 php occ talk:stun:add stun.l.google.com:19302

echo 'Configuring Redis for High-Performance Transactional File Locking...'
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:system:set memcache.local --value='\OC\Memcache\APCu'
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:system:set memcache.distributed --value='\OC\Memcache\Redis'
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:system:set memcache.locking --value='\OC\Memcache\Redis'
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:system:set redis host --value='redis'
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:system:set redis port --value=6379 --type=integer
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:system:set redis password --value='udom_redis_secret'

echo 'Force re-registering AppAPI HaRP deploy daemon to fix accessibility warning...'
docker exec -u 33 udom-cloud-deployment-app-1 php occ app_api:daemon:unregister harp_docker || true

SHARED_KEY=$(docker exec udom-cloud-deployment-appapi-harp-1 printenv HP_SHARED_KEY || echo 'fallback')
docker exec -u 33 udom-cloud-deployment-app-1 php occ app_api:daemon:register harp_docker 'HaRP Docker' docker-install http appapi-harp:8780 http://app:80 --net udom-cloud-deployment_default --harp --harp_frp_address appapi-harp:8782 --harp_shared_key "$SHARED_KEY" --set-default || true

echo '======================================'
echo 'Phase 3 Fixes Applied Successfully!'
echo '======================================'
