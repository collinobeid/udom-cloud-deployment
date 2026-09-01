# setup_udom.ps1 - Automates UDOM Cloud Enterprise Configurations for Windows PowerShell

Write-Host "Waiting for Nextcloud to be fully installed..."
while ($true) {
    $status = docker exec -u 33 udom-cloud-deployment-app-1 php occ status 2>&1
    if ($status -match "installed: true") {
        break
    }
    Start-Sleep -Seconds 5
}

Write-Host "Nextcloud is ready. Configuring UDOM Customizations..."

# 1. UI Branding & Theme Injection
Write-Host "Preparing UI Customization structure for Taofina..."

# 2. Security & Policy Enforcement
Write-Host "Enabling Security Modules and 2FA..."
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:install suspicious_login
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:enable suspicious_login
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:install bruteforcesettings
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:enable bruteforcesettings
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:install twofactor_totp
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:enable twofactor_totp

# 3. Active Directory / LDAP Mockup
Write-Host "Configuring LDAP connection to SRMS..."
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:enable user_ldap
$configOutput = docker exec -u 33 udom-cloud-deployment-app-1 php occ ldap:create-empty-config
$configId = ($configOutput -split ' ')[-1]
docker exec -u 33 udom-cloud-deployment-app-1 php occ ldap:set-config $configId ldapHost 'ldap://srms.udom.ac.tz'
docker exec -u 33 udom-cloud-deployment-app-1 php occ ldap:set-config $configId ldapPort '389'
docker exec -u 33 udom-cloud-deployment-app-1 php occ ldap:set-config $configId ldapBase 'dc=udom,dc=ac,dc=tz'

# 4. Custom Skeleton Directory (Student files)
Write-Host "Setting custom UDOM onboarding files..."
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:system:set skeletondirectory --value='/var/www/html/custom_assets/skeleton'

# 5. Local AI Integration (Ollama + Qwen3)
Write-Host "Setting up Local AI Integration..."
# Ensure Ollama is running and download the model in the background
Start-Job -ScriptBlock { docker exec udom-cloud-deployment-ollama-1 ollama run qwen2.5 } | Out-Null

# Install Nextcloud Assistant and OpenAI integration
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:install --force --allow-unstable assistant
docker exec -u 33 udom-cloud-deployment-app-1 php occ app:install --force --allow-unstable integration_openai

# Configure API endpoint
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:app:set integration_openai api_url --value="http://ollama:11434/v1"
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:app:set integration_openai api_key --value="ollama"
docker exec -u 33 udom-cloud-deployment-app-1 php occ config:app:set assistant integration --value="integration_openai"

Write-Host "=================================================="
Write-Host "UDOM Cloud Configuration Complete!"
Write-Host "=================================================="
