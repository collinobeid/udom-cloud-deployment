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
