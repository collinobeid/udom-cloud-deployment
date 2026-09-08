#!/usr/bin/env bash
#
# scripts/security-setup.sh
#
# Applies the Security/Identity/Access domain configuration to a
# freshly started UDOM Cloud Nextcloud instance.
#
# PREREQUISITES (must be done manually first — see README):
#   1. `docker compose up -d` has been run and containers are healthy.
#   2. The LDAP base connection has already been configured via the
#      Nextcloud admin UI or `occ ldap:set-config` — this requires the
#      LDAP bind (agent) password, which is NEVER stored in this repo.
#      Required settings: ldapHost, ldapPort, ldapBase, ldapBaseUsers,
#      ldapBaseGroups, ldapAgentName, ldapAgentPassword, ldapLoginFilter.
#   3. Test/production LDAP users have been provisioned in the
#      directory (this script does not create LDAP accounts).
#
# USAGE:
#   bash scripts/security-setup.sh
#
# SAFETY:
#   - Contains ONLY reproducible `occ` configuration commands.
#   - Contains NO passwords, LDAP bind credentials, TOTP secrets,
#     backup codes, or other credential material.
#   - Safe to re-run: every command is a direct config:set/set-config
#     call, so re-running just re-applies the same values.
#   - Does not use `docker exec` with a hard-coded container name;
#     uses `docker compose exec` against the `app` service instead,
#     so it works regardless of the Compose project name.

set -euo pipefail

OCC="docker compose exec -T -u www-data app php occ"
LDAP_EXEC="docker compose exec -T ldap"

echo "=== Waiting for Nextcloud to be ready ==="
READY=0
for i in $(seq 1 30); do
  if ${OCC} status --output=json >/dev/null 2>&1; then
    READY=1
    break
  fi
  echo "  Nextcloud not ready yet, retrying in 5s... (${i}/30)"
  sleep 5
done

if [ "${READY}" -ne 1 ]; then
  echo "ERROR: Nextcloud did not become ready in time. Aborting." >&2
  exit 1
fi
echo "Nextcloud is ready."
echo

echo "=== [1/6] LDAP: username/display-name/group mapping ==="
# Assumes LDAP base connection (host/port/base DN/agent DN/agent
# password/login filter) is already configured manually — see README.
# Fixes: LDAP accounts showing raw UUIDs instead of uid/cn.
${OCC} ldap:set-config s01 ldapExpertUsernameAttr uid
${OCC} ldap:set-config s01 ldapUserDisplayName cn

# Group detection: assumes groupOfNames + member-attribute groups
# with no memberOf overlay on the LDAP server (adjust if your
# directory schema differs).
${OCC} ldap:set-config s01 ldapGroupFilterObjectclass groupOfNames
${OCC} ldap:set-config s01 ldapGroupFilter "(&(objectclass=groupOfNames))"
${OCC} ldap:set-config s01 ldapGroupMemberAssocAttr member
${OCC} ldap:set-config s01 useMemberOfToDetectMembership 0
${OCC} ldap:set-config s01 ldapConfigurationActive 1
${OCC} ldap:set-config s01 ldapAgentPassword "${LDAP_ADMIN_PASSWORD}"
echo


echo "=== [1b/6] LDAP test-user password re-seed ==="
# These accounts's userPassword can silently revert to the LDIF placeholder
# after certain restarts (observed 2026-09-08). Re-set them idempotently
# from env vars (never hardcoded) so logins keep working.
${LDAP_EXEC} ldappasswd -x -D "cn=admin,dc=udom,dc=local" -w "${LDAP_ADMIN_PASSWORD}" -s "${LDAP_STUDENT_TEST_PASSWORD}" "uid=t21-03-05678,ou=people,dc=udom,dc=local" || true
${LDAP_EXEC} ldappasswd -x -D "cn=admin,dc=udom,dc=local" -w "${LDAP_ADMIN_PASSWORD}" -s "${LDAP_STAFF_TEST_PASSWORD}" "uid=stf-2031,ou=people,dc=udom,dc=local" || true
echo
echo "=== [2/6] Password policy ==="
${OCC} app:enable password_policy
${OCC} config:app:set password_policy minimal_length --value="10"
${OCC} config:app:set password_policy enforceNonCommonPassword --value="1"
${OCC} config:app:set password_policy enforceNumericCharacters --value="1"
${OCC} config:app:set password_policy enforceUpperLowerCase --value="1"
${OCC} config:app:set password_policy enforceSpecialCharacters --value="1"
echo

echo "=== [3/6] Brute-force protection ==="
${OCC} config:system:set auth.bruteforce.protection.enabled --value=true --type=boolean
echo

echo "=== [4/6] Audit / suspicious-login logging ==="
${OCC} app:enable admin_audit
${OCC} config:system:set log.audit.file --value="/var/www/html/data/audit.log"
# loglevel must be <=1 (Info) or admin_audit events are silently dropped.
${OCC} config:system:set loglevel --value=1 --type=integer
echo

echo "=== [5/6] Quotas ==="
${OCC} config:app:set files default_quota --value="5 GB"
# Staff quota override — no group-quota app installed, so this is a
# named per-user override via `user:setting`, not a group-level setting.
# Only runs if the user already exists (e.g. after their first LDAP login).
if ${OCC} user:info stf-2031 >/dev/null 2>&1; then
  ${OCC} user:setting stf-2031 files quota "20 GB"
else
  echo "  (skipped: stf-2031 not yet provisioned — run again after their first LDAP login)"
fi
echo

echo "=== [6/6] Done ==="
echo "Automated configuration complete."
echo
echo "MANUAL STEPS STILL REQUIRED (see README):"
echo "  - 2FA (TOTP) enrollment: each admin/user must enable this"
echo "    individually via Settings > Security > Two-Factor Authentication."
echo "    This cannot be scripted — secrets must never be stored in git."
echo "  - Backup codes: generated per-user in the same Security settings"
echo "    page; must be saved by the user directly, not stored anywhere."
