# Udom Cloud Deployment (Nextcloud + AI Assistant)

This repository contains the complete, reproducible Nextcloud infrastructure for our team, integrated with a local, real-time AI Assistant powered by Ollama.

## Quickstart Installation

This deployment is built entirely on Docker and is compatible with **Windows**, **Linux**, and **macOS**.
You do not need PHP or local web servers installed—only Docker Desktop (or Docker Engine).

1. Clone the repository:
   ```bash
   git clone <repo-url>
   cd udom-cloud-deployment
   ```

2. Start the services:
   ```bash
   docker-compose up -d
   ```

### What happens automatically?
The initialization is completely automated via the `ai-setup` service. Once you run the command above, the setup will:
- Spin up Nextcloud and Mariadb.
- Start a local Ollama AI backend.
- Silently wait for Nextcloud to finish its first-run wizard.
- Download the required local AI model (`qwen2.5:1.5b`).
- Install and configure the Nextcloud Assistant and OpenAI integration apps.
- Patch known Nextcloud 34 UI and cron bugs.
- Configure a continuous background worker (`ai-worker`) for instantaneous real-time AI responses.

## Updating an Existing Installation

If you already have this repository running and want to pull the latest changes, run:

```bash
git pull
docker-compose pull
docker-compose up -d --force-recreate
```
**Safety Guarantee**: The `ai-setup` container is strictly idempotent. Running it on an existing database/volume will NOT overwrite your user files, delete databases, or reset your personal settings. It safely checks for dependencies before running.

## AI Architecture

We use a modern, real-time asynchronous architecture for AI task processing:

```text
Nextcloud Assistant (Frontend)
        ↓
Nextcloud TaskProcessing (Core)
        ↓
AI Task Queue (Database)
        ↓
Dedicated AI Worker (`ai-worker` Docker container)
        ↓
Local AI Provider (`integration_openai`)
        ↓
Ollama API (`ollama` container)
        ↓
qwen2.5:1.5b (Local LLM)
        ↓
Nextcloud Assistant (Response)
```

### Key Architectural Decisions
- **Dedicated AI Worker**: By default, Nextcloud processes background jobs every 5 minutes. We run a dedicated `occ taskprocessing:worker` container to bypass this delay and provide instantaneous chat responses.
- **Image Generation Disabled**: Our Ollama backend is designed strictly for Text and Vision Large Language Models (LLMs). Since it does not support `text-to-image` architectures like Stable Diffusion, the Nextcloud image generation task type is intentionally disabled during setup to prevent UI crash errors.
- **Patched Assistant**: The legacy Assistant app (v3.5.0) relies on removed API endpoints and fails fatally if a user deletes a chat session while a request is processing. Our setup auto-injects patches into the Nextcloud volume on startup to safely handle these edge cases.

## Troubleshooting

- **Check AI Worker Logs**: If the AI is not responding, ensure the worker is running:
  ```bash
  docker logs udom-cloud-deployment-ai-worker-1
  ```
- **Check Initialization Logs**: If the setup seems incomplete, verify the `ai-setup` container ran successfully:
  ```bash
  docker logs udom-cloud-deployment-ai-setup-1
  ```
- **Check Ollama Models**: Verify your model downloaded successfully:
  ```bash
  docker exec udom-cloud-deployment-ollama-1 ollama list
  ```
## Security / Identity / Access — Setup

This domain covers LDAP authentication, password policy, brute-force
protection, 2FA, quotas, and audit logging. Most of this is automated
via `scripts/security-setup.sh`; a few steps must be done manually.

### 1. Manual prerequisite — LDAP base connection

Before running the setup script, the LDAP base connection must be
configured once, manually, since it requires the LDAP bind (agent)
password — which is never stored in this repository.

Configure via the Nextcloud admin UI (Settings → Administration →
LDAP/AD integration) or via `occ ldap:set-config s01 <key> <value>`.
Required settings:

- `ldapHost`, `ldapPort`
- `ldapBase`, `ldapBaseUsers`, `ldapBaseGroups`
- `ldapAgentName`, `ldapAgentPassword`
- `ldapLoginFilter`

### 2. Automated setup

Once the containers are running and the LDAP base connection above is
configured:

```bash
bash scripts/security-setup.sh
```

This script:
- Fixes LDAP username/display-name/group mapping
- Configures password policy (min length 10, complexity rules, blocks
  common passwords)
- Enables brute-force protection
- Enables audit logging (`admin_audit`) to a dedicated log file
- Sets a default 5GB quota, with a 20GB override for staff (`stf-2031`)

The script is idempotent — safe to re-run at any time.

### 3. Manual step — 2FA enrollment

2FA (TOTP) and backup codes must be enabled per-user via
**Settings → Security → Two-Factor Authentication**. This cannot be
scripted, since secrets and backup codes must never be stored in git.
