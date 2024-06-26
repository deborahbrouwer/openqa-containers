#!/bin/bash

# Find the new certs in /var/lib/httpd/md/domains/openqa.fedorainfracloud.org/

set -e

echo "Generating new certificates"
sed -i '/#ServerName www.example.com:80/a\ServerName openqa.fedorainfracloud.org' /etc/httpd/conf/httpd.conf

# Uncomment this part of the config to enable the mod_md module
sed -i '/<IfModule mod_md.c>/,/<\/IfModule>/ s/^#\?//' /conf/openqa-proxy-ssl.conf

# Apache mod_md will request them the configs from the MDCertificateAuthority as
# specified in openqa-ssl.conf but only if there are no other certificates configured
# so comment out these configs
sed -i '/SSLCertificateFile/s/^/#/' /etc/httpd/conf.d/ssl.conf
sed -i '/SSLCertificateKeyFile/s/^/#/' /etc/httpd/conf.d/ssl.conf
sed -i '/SSLCertificateFile/s/^/#/' /conf/openqa-proxy-ssl.conf
sed -i '/SSLCertificateKeyFile/s/^/#/' /conf/openqa-proxy-ssl.conf

# restart
httpd -DSSL

# Copy new configs into /conf so that they will persist beyond the container's lifetime
cp /var/lib/httpd/md/domains/openqa.fedorainfracloud.org/pubcert.pem /conf/pubcert.pem || true
cp /var/lib/httpd/md/domains/openqa.fedorainfracloud.org/privkey.pem /conf/privkey.pem || true
