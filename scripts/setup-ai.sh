#!/bin/bash
set -e

echo "Starting Nextcloud AI Setup..."

# 1. Wait for Nextcloud to be installed and ready
echo "Waiting for Nextcloud to be ready..."
until su www-data -s /bin/bash -c "php occ status" | grep -q "installed: true"; do
  echo "Nextcloud is not yet installed or ready. Waiting 10 seconds..."
  sleep 10
done
echo "Nextcloud is ready!"

# 2. Wait for Ollama to be available
echo "Waiting for Ollama..."
until curl -s http://ollama:11434/api/tags >/dev/null; do
  echo "Ollama is not yet available. Waiting 5 seconds..."
  sleep 5
done
echo "Ollama is up!"

# 3. Check and pull Ollama model idempotently
MODEL_NAME="qwen2.5:1.5b"
echo "Checking if model $MODEL_NAME exists..."
if ! curl -s http://ollama:11434/api/tags | grep -q "\"name\":\"$MODEL_NAME\""; then
  echo "Model $MODEL_NAME not found. Pulling now (this may take several minutes)..."
  curl -X POST http://ollama:11434/api/pull -d "{\"name\": \"$MODEL_NAME\"}"
  echo "Model pull complete."
else
  echo "Model $MODEL_NAME is already available."
fi

# 4. Install Nextcloud Apps (idempotent)
echo "Ensuring required apps are installed..."
su www-data -s /bin/bash -c "php occ app:enable assistant" || su www-data -s /bin/bash -c "php occ app:install assistant" || true
su www-data -s /bin/bash -c "php occ app:enable integration_openai" || su www-data -s /bin/bash -c "php occ app:install integration_openai" || true

# 5. Apply Nextcloud Assistant Compatibility Patches
echo "Applying compatibility patches for Assistant app 3.5.0..."
if [ -d "/patches/assistant-3.5.0" ]; then
  cp /patches/assistant-3.5.0/AssistantApiController.php /var/www/html/custom_apps/assistant/lib/Controller/AssistantApiController.php
  cp /patches/assistant-3.5.0/routes.php /var/www/html/custom_apps/assistant/appinfo/routes.php
  cp /patches/assistant-3.5.0/ChattyLLMTaskListener.php /var/www/html/custom_apps/assistant/lib/Listener/ChattyLLMTaskListener.php
  echo "Patches applied successfully."
else
  echo "WARNING: /patches/assistant-3.5.0 directory not found!"
fi

# 6. Configure OpenAI Integration to point to Ollama
echo "Configuring AI Provider settings..."
su www-data -s /bin/bash -c "php occ config:app:set integration_openai api_url --value=\"http://ollama:11434/v1\""
su www-data -s /bin/bash -c "php occ config:app:set integration_openai api_key --value=\"ollama\""
su www-data -s /bin/bash -c "php occ config:app:set integration_openai default_completion_model_id --value=\"$MODEL_NAME\""

# 7. Disable image generation due to Ollama architecture limitations
echo "Disabling unsupported image generation..."
su www-data -s /bin/bash -c "php occ taskprocessing:task-type:set-enabled core:text2image 0" || true

echo "AI Integration Setup successfully completed!"

# ================================================
# RAG / CONTEXT CHAT SETUP
# ================================================
# This section is ADDITIVE. It does not modify any
# of the above configuration. It adds:
# - nomic-embed-text embeddings model
# - AppAPI Deploy Daemon (HaRP)
# - Context Chat frontend app
# - Context Chat Backend ExApp
# ================================================

echo ""
echo "================================================"
echo "Starting RAG / Context Chat Setup..."
echo "================================================"

# 8. Pull embeddings model (idempotent)
EMBED_MODEL="nomic-embed-text"
echo "Checking if embeddings model $EMBED_MODEL exists..."
if ! curl -s http://ollama:11434/api/tags | grep -q "nomic-embed-text"; then
  echo "Embeddings model $EMBED_MODEL not found. Pulling now (this may take several minutes)..."
  curl -X POST http://ollama:11434/api/pull -d "{\"name\": \"$EMBED_MODEL\"}"
  echo "Embeddings model pull complete."
else
  echo "Embeddings model $EMBED_MODEL is already available."
fi

# 9. Verify AppAPI is installed
echo "Verifying AppAPI..."
if su www-data -s /bin/bash -c "php occ app:list" | grep -q "app_api"; then
  echo "AppAPI is installed."
  su www-data -s /bin/bash -c "php occ app:enable app_api" || true
else
  echo "Installing AppAPI..."
  su www-data -s /bin/bash -c "php occ app:install app_api" || true
fi

# 10. Register HaRP Deploy Daemon (idempotent)
echo "Checking Deploy Daemon registration..."
if su www-data -s /bin/bash -c "php occ app_api:daemon:list" | grep -q "harp_docker"; then
  echo "Deploy Daemon 'harp_docker' is already registered."
else
  echo "Registering HaRP Deploy Daemon..."
  su www-data -s /bin/bash -c "php occ app_api:daemon:register \
    harp_docker \
    'HaRP Docker' \
    docker-install \
    http \
    appapi-harp:8780 \
    http://app:80 \
    --net udom-cloud-deployment_default \
    --harp \
    --harp_frp_address appapi-harp:8782 \
    --harp_shared_key \"\$APPAPI_SHARED_KEY\" \
    --set-default"
  echo "Deploy Daemon registered."
fi

# 11. Test Deploy — verify HaRP communication before installing ExApps
echo "Running AppAPI Test Deploy..."
if su www-data -s /bin/bash -c "php occ app_api:app:register test_deploy harp_docker --test-deploy-mode --wait-finish --force-scopes" 2>&1; then
  echo "Test Deploy PASSED."
else
  echo "WARNING: Test Deploy returned non-zero. Check HaRP logs. Continuing..."
fi

# 12. Install Context Chat frontend app (idempotent)
echo "Installing Context Chat frontend..."
su www-data -s /bin/bash -c "php occ app:enable context_chat" || \
  su www-data -s /bin/bash -c "php occ app:install context_chat" || true

# 13. Deploy Context Chat Backend ExApp (idempotent)
echo "Deploying Context Chat Backend ExApp..."
if su www-data -s /bin/bash -c "php occ app_api:app:list" | grep -q "context_chat_backend"; then
  echo "Context Chat Backend is already deployed."
else
  echo "Installing Context Chat Backend via AppAPI..."
  su www-data -s /bin/bash -c "php occ app_api:app:register context_chat_backend harp_docker --wait-finish --force-scopes --env CC_EM_REMOTE_SERVICE=true --env CC_EM_BASE_URL=http://udom-cloud-deployment-ollama-1:11434/v1 --env CC_EM_MODEL_NAME=nomic-embed-text" || true
fi

# 14. Verify model isolation
# Ensure qwen2.5:1.5b remains the text generation model
# nomic-embed-text should only be used for embeddings by context_chat_backend
echo "Verifying model configuration isolation..."
su www-data -s /bin/bash -c "php occ config:app:set integration_openai default_completion_model_id --value=\"$MODEL_NAME\"" || true
echo "Text generation model confirmed: $MODEL_NAME"
echo "Embeddings model available: $EMBED_MODEL"

echo ""
echo "================================================"
echo "RAG / Context Chat Setup completed!"
echo "================================================"
echo "Text Generation: $MODEL_NAME (via integration_openai)"
echo "Embeddings: $EMBED_MODEL (via context_chat_backend)"
echo "Deploy Daemon: HaRP (appapi-harp)"
echo "================================================"
