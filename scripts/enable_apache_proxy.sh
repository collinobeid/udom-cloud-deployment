#!/bin/bash
set -e
echo 'Enabling Apache proxy modules for AppAPI...'
a2enmod proxy proxy_http
