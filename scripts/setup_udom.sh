#!/bin/bash
# setup_udom.sh - Automates UDOM Cloud Enterprise Configurations

echo "Waiting for Nextcloud to be fully installed..."
until docker exec -u 33 udom-cloud-deployment-app-1 php occ status | grep -q "installed: true"; do
  sleep 5
done

echo "Nextcloud is ready. Configuring UDOM Customizations..."

# 1. UI Branding & Theme Injection
echo "Preparing UI Customization structure for Taofina..."
# NOTE FOR TAOFINA (UI/UX):
# All UI branding, custom CSS, and logo injections should be scripted here.
# Place your assets in the customizations/theme/ folder.'

# 2. Security & Policy Enforcement
echo "Enabling Security Modules and 2FA..."
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:install suspicious_login
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:enable suspicious_login
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:install bruteforcesettings
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:enable bruteforcesettings
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:install twofactor_totp
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:enable twofactor_totp

echo "Applying UDOM IT Acceptable Use Policy..."
# Note: terms_of_service app is not available in the NC34 appstore by default.
# docker exec -u 33 udom-cloud-deployment-app-1 php occ app:install terms_of_service
# docker exec -u 33 udom-cloud-deployment-app-1 php occ app:enable terms_of_service
# TOS="# UDOM IT Acceptable Use Policy\n\nBy accessing UDOM Cloud..."
# docker exec -u 33 udom-cloud-deployment-app-1 bash -c "php occ terms_of_service:term:set -l en \"$TOS\""

# 3. Active Directory / LDAP Mockup
echo "Configuring LDAP connection to SRMS..."
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:enable user_ldap
CONFIG_ID=$(docker exec -u 33 udom-cloud-deployment-app-1 php occ ldap:create-empty-config | awk '{print $NF}')
docker exec -u 33 udom-cloud-deployment-app-1 php occ ldap:set-config $CONFIG_ID ldapHost 'ldap://srms.udom.ac.tz' || true
docker exec -u 33 udom-cloud-deployment-app-1 php occ ldap:set-config $CONFIG_ID ldapPort '389' || true
docker exec -u 33 udom-cloud-deployment-app-1 php occ ldap:set-config $CONFIG_ID ldapBase 'dc=udom,dc=ac,dc=tz' || true

# 4. Custom Skeleton Directory (Student files)
echo "Setting custom UDOM onboarding files..."
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:system:set skeletondirectory --value='/var/www/html/custom_assets/skeleton'

# 5. Local AI Integration (Ollama + Qwen3)
echo "Setting up Local AI Integration..."
# Ensure Ollama is running and download the model in the background
docker exec udom-cloud-deployment-ollama-1 sh -c 'ollama run qwen2.5:1.5b > /dev/null 2>&1 &'

# Install Nextcloud Assistant and OpenAI integration
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:install --force --allow-unstable assistant
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:install --force --allow-unstable integration_openai

# Configure API endpoint and Model
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:app:set integration_openai url --value="http://ollama:11434/v1"
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:app:set integration_openai api_key --value="ollama"
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:app:set integration_openai default_completion_model_id --value="qwen2.5:1.5b"
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:app:set assistant integration --value="integration_openai"

echo "=================================================="
echo "UDOM Cloud Configuration Complete!"
echo "=================================================="
