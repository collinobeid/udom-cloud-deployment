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
#   bash scripts/security-setup.sh          (from host)
#   /bin/bash /security-setup.sh            (from inside security-init container)
#
# SAFETY:
#   - Contains ONLY reproducible `occ` configuration commands.
#   - Contains NO passwords, LDAP bind credentials, TOTP secrets,
#     backup codes, or other credential material.
#   - Safe to re-run: every command is a direct config:set/set-config
#     call, so re-running just re-applies the same values.
#   - Auto-detects whether it's running on the host (uses
#     `docker compose exec`) or inside a container with direct
#     filesystem access to Nextcloud (e.g. the security-init service).
set -euo pipefail

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  RUN_CONTEXT="host"
else
  RUN_CONTEXT="container"
fi

occ() {
  if [ "${RUN_CONTEXT}" = "host" ]; then
    docker compose exec -T -u www-data app php occ "$@"
  else
    (cd /var/www/html && php occ "$@")
  fi
}

ldap_set_password() {
  local dn="$1" pass="$2"
  if [ "${RUN_CONTEXT}" = "host" ]; then
    docker compose exec -T ldap ldappasswd -x -D "cn=admin,dc=udom,dc=local" -w "${LDAP_ADMIN_PASSWORD}" -s "${pass}" "${dn}" || true
  else
    php -r '$dn=$argv[1];$pass=$argv[2];$adminPw=$argv[3];$c=ldap_connect("ldap://ldap:389");ldap_set_option($c,LDAP_OPT_PROTOCOL_VERSION,3);if(!@ldap_bind($c,"cn=admin,dc=udom,dc=local",$adminPw)){fwrite(STDERR,"LDAP bind failed for $dn\n");exit(0);}@ldap_mod_replace($c,$dn,["userPassword"=>$pass]);ldap_unbind($c);' "${dn}" "${pass}" "${LDAP_ADMIN_PASSWORD}" || true
  fi
}

echo "=== Waiting for Nextcloud to be ready ==="
READY=0
for i in $(seq 1 30); do
  if occ status --output=json >/dev/null 2>&1; then
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
occ ldap:set-config s01 ldapExpertUsernameAttr uid
occ ldap:set-config s01 ldapUserDisplayName cn

# Group detection: assumes groupOfNames + member-attribute groups
# with no memberOf overlay on the LDAP server (adjust if your
# directory schema differs).
occ ldap:set-config s01 ldapGroupFilterObjectclass groupOfNames
occ ldap:set-config s01 ldapGroupFilter "(&(objectclass=groupOfNames))"
occ ldap:set-config s01 ldapGroupMemberAssocAttr member
occ ldap:set-config s01 useMemberOfToDetectMembership 0

occ ldap:set-config s01 ldapConfigurationActive 1
occ ldap:set-config s01 ldapAgentPassword "${LDAP_ADMIN_PASSWORD}"
echo

echo "=== [1b/6] LDAP test-user password re-seed ==="
# These accounts' userPassword can silently revert to the LDIF placeholder
# after certain restarts (observed 2026-09-08). Re-set them idempotently
# from env vars (never hardcoded) so logins keep working.
ldap_set_password "uid=t21-03-05678,ou=people,dc=udom,dc=local" "${LDAP_STUDENT_TEST_PASSWORD}"
ldap_set_password "uid=stf-2031,ou=people,dc=udom,dc=local" "${LDAP_STAFF_TEST_PASSWORD}"
echo

echo "=== [2/6] Password policy ==="
occ app:enable password_policy
occ config:app:set password_policy minimal_length --value="10"
occ config:app:set password_policy enforceNonCommonPassword --value="1"
occ config:app:set password_policy enforceNumericCharacters --value="1"
occ config:app:set password_policy enforceUpperLowerCase --value="1"
occ config:app:set password_policy enforceSpecialCharacters --value="1"
echo

echo "=== [3/6] Brute-force protection ==="
occ config:system:set auth.bruteforce.protection.enabled --value=true --type=boolean
echo

echo "=== [4/6] Audit / suspicious-login logging ==="
occ app:enable admin_audit
occ config:system:set log.audit.file --value="/var/www/html/data/audit.log"
# loglevel must be <=1 (Info) or admin_audit events are silently dropped.
occ config:system:set loglevel --value=1 --type=integer
echo

echo "=== [5/6] Quotas ==="
occ config:app:set files default_quota --value="5 GB"
# Staff quota override — no group-quota app installed, so this is a
# named per-user override via `user:setting`, not a group-level setting.
# Only runs if the user already exists (e.g. after their first LDAP login).
if occ user:info stf-2031 >/dev/null 2>&1; then
  occ user:setting stf-2031 files quota "20 GB"
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
