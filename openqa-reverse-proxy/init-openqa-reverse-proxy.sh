#!/bin/bash
set -ex
function cleanup() {
  echo "Return ownership of bound directories back to container host."
  chown -R root:root /etc/httpd/logs
  exit
}
trap cleanup SIGTERM SIGINT

function configure_apache() {

  # Production configuration
  if [ -f "/conf/privkey.pem" ]; then
    echo "Using production SSL/TLS certificates"

    ln -s /conf/pubcert.pem /etc/pki/tls/certs/pubcert.pem
    ln -s /conf/privkey.pem /etc/pki/tls/private/privkey.pem

    sed -i '/#ServerName www.example.com:80/a\ServerName openqa.fedorainfracloud.org' /etc/httpd/conf/httpd.conf

    # Use the configs that include mod_md
    ln -s /conf/openqa-ssl.conf /etc/httpd/conf.d/openqa-ssl.conf
    ln -s /conf/openqa.conf /etc/httpd/conf.d/openqa.conf
  else
    # Local configuration relies on on /etc/httpd/conf.d/ssl.conf 
    echo "Using local SSL/TLS certificates"

    local mojo_resources=$(perl -e 'use Mojolicious; print(Mojolicious->new->home->child("Mojo/IOLoop/resources"))')
    cp "$mojo_resources"/server.crt /etc/httpd/tls/localhost.crt
    cp "$mojo_resources"/server.key /etc/httpd/tls/localhost.key
    cp "$mojo_resources"/server.crt /etc/httpd/tls/ca.crt
  fi
}

# RUN dnf install -y openqa-httpd mod_ssl mod_proxy_html mod_session mod_md
dnf install -y mod_md perl perl-Mojolicious procps-ng
ln -s /etc/httpd/conf.modules.d/00-base.conf /etc/httpd/conf.modules.d/00-base.load
ln -s /etc/httpd/conf.modules.d/00-ssl.conf /etc/httpd/conf.modules.d/00-ssl.load
/usr/libexec/httpd-ssl-gencerts

configure_apache

httpd -DSSL || true
while true; do
    sleep 6000
done

configure_apache
# httpd -DSSL

cleanup