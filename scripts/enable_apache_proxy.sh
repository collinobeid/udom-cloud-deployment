#!/bin/bash
# Do NOT use set -e here — a2enmod returns exit code 1 when modules are
# already enabled (e.g. on container restart), which would kill the container.
echo 'Enabling Apache proxy modules for AppAPI...'
a2enmod proxy proxy_http || true
echo 'Apache proxy modules ready.'
