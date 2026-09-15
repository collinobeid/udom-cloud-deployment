FROM nextcloud:34.0.3-apache
RUN a2enmod proxy proxy_http
