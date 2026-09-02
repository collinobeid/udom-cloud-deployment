# UDOM Cloud Project: Team Organization & Workflow

This document outlines the roles, responsibilities, and collaborative workflow for the UDOM Cloud Enterprise Deployment project. This ensures a professional, university-standard approach to our DevOps pipeline.

## 👥 Recommended 5-Member Structure

| Member      | Primary Role                                 | Responsibilities                                                                                                                                                                                                                                          |
| ----------- | -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Collin**  | 🧠 Project Lead, DevOps & AI Architect       | GitHub, Docker/infrastructure, architecture, deployment, automation, networking, HTTPS/reverse proxy, CI/CD, cron/background jobs, system integration, **Ollama, Nextcloud Assistant, RAG/Context Chat, AI integration**, PR review, project coordination |
| **Taofina** | 🎨 Frontend, UI/UX & Customization           | UDOM branding, custom theme/CSS, login page, logos/backgrounds, Skeleton directory, accessibility, responsive UI, desktop/mobile testing                                                                                                                  |
| **Ahmed**   | 🔐 Security, Identity & Access Administrator | LDAP/SRMS simulation, authentication, groups, 2FA, password/security policies, quotas, brute-force protection, suspicious-login monitoring, security hardening, access control, audit/security configuration                                              |
| **Paschal** | 🗄️ Database, Storage, Backup & Monitoring   | MariaDB, database optimization, storage architecture, external storage, quotas/storage monitoring, backups, restore procedures, disaster recovery, logs, operational monitoring                                                                           |
| **Levson**  | 🤝 Collaboration, Apps & QA Lead             | Nextcloud Talk, TURN/coturn, Collabora/Nextcloud Office, app lifecycle, integrations, real-time collaboration, **system testing, integration testing, regression testing, UAT, final validation, testing documentation**                                  |

### Collin — The System Backbone

```text
Infrastructure
     +
DevOps
     +
GitHub
     +
Automation
     +
Architecture
     +
AI
```

Your AI responsibilities remain:

```text
Ollama
   ↓
AI Model
   ↓
Nextcloud Assistant
   ↓
Context Chat / RAG
   ↓
University-specific AI functionality
```

---

## 🛡️ The Golden Rule of Ownership

Every member owns **four things** for their area:

```text
IMPLEMENT
   ↓
CONFIGURE
   ↓
TEST
   ↓
DOCUMENT
```

For example, Ahmed doesn't merely "configure LDAP." Ahmed owns:
```text
LDAP
 ├── Implementation
 ├── Configuration
 ├── Security testing
 ├── Failure testing
 └── Documentation
```

Likewise:
```text
Taofina (UI)
 ├── Build
 ├── Responsive test
 ├── Browser test
 └── Documentation

Paschal (Database/Storage)
 ├── Configure
 ├── Performance test
 ├── Backup/restore test
 └── Documentation

Levson (Collaboration)
 ├── Configure
 ├── Multi-user test
 ├── Integration test
 └── Documentation

Collin (Infrastructure/AI)
 ├── Deploy
 ├── Integration test
 ├── Failure/recovery test
 └── Documentation
```

This prevents the classic problem where everyone says **"my part works"**, but nobody owns whether the **whole Nextcloud system works together**.

---

## 🏗️ Final 5-Person Structure

```text
                         UDOM CLOUD
                             │
              ┌──────────────┴──────────────┐
              │                             │
        COLLIN — LEAD                  TEAM MEMBERS
        DevOps + AI                         │
              │                             │
      ┌───────┼────────┬────────────┬───────┴───────┐
      │       │        │            │               │
      ▼       ▼        ▼            ▼               ▼
 Infrastructure   UI/UX       Security       Database/Storage   Collaboration/QA
   + AI          Taofina       Ahmed             Paschal            Levson
```

---

## 🔄 Standard Operating Procedure (Workflow)

To prevent team members from overwriting each other's work and to maintain a professional GitHub history, we will follow the **Feature Branch Workflow**.

### Step 1: Sync Your Local Environment
Every time you start working, ensure you have the latest code from your team:
```bash
git checkout main
git pull origin main
docker-compose up -d
```

### Step 2: Create a Feature Branch
Never work directly on the `main` branch. Create a new branch for your specific task:
```bash
# Example for Taofina:
git checkout -b feature/udom-login-theme

# Example for Ahmed:
git checkout -b feature/ldap-security
```

### Step 3: Develop and Test
Make your changes to the files (e.g., editing CSS, updating the setup script). Test them locally in your browser at `http://localhost:8080` to ensure they work.

### Step 4: Commit and Push
Once your feature is working locally, use GitHub Desktop to commit your changes with a clear, descriptive summary. Push the branch to GitHub.

### Step 5: Pull Request (PR) & Code Review
1. Go to GitHub.com and open a **Pull Request (PR)** from your feature branch into the `main` branch.
2. Describe what you changed in the PR description.
3. **Collin** (or another peer) will review the code to ensure it doesn't break the server.
4. Once approved, the PR is merged into `main`.
5. Everyone else runs `git pull origin main` to receive the new feature!
