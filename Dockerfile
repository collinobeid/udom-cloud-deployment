FROM nextcloud:34.0.3-apache

# Pre-enable Apache proxy modules at build time (runs as root).
# This eliminates the need for the hook script that was crashing
# with Permission Denied on container restarts.
RUN a2enmod proxy proxy_http

