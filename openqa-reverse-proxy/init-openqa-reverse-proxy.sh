#!/bin/bash
set -ex
function cleanup() {
echo "Return ownership of bound directories back to container host."
chown -R root:root /etc/httpd/logs
exit
}
trap cleanup SIGTERM SIGINT


CONFIG_DIR=/etc/httpd/conf.d/

dnf install -y mod_md perl perl-Mojolicious procps-ng mod_proxy_html

ln -s /conf/openqa-proxy-ssl.conf `$CONFIG_DIR/openqa-proxy-ssl.conf`
ln -s /conf/openqa-proxy.conf `$CONFIG_DIR/openqa-proxy.conf`

ln -s /etc/httpd/conf.modules.d/00-base.conf /etc/httpd/conf.modules.d/00-base.load
ln -s /etc/httpd/conf.modules.d/00-ssl.conf /etc/httpd/conf.modules.d/00-ssl.load
/usr/libexec/httpd-ssl-gencerts


# Production configuration
if [ -f "/conf/privkey.pem" ]; then
  echo "Using production SSL/TLS certificates"

  ln -s /conf/pubcert.pem `$CONFIG_DIR/pubcert.pem`
  ln -s /conf/privkey.pem `$CONFIG_DIR/privkey.pem`

  sed -i "s/SSLCertificateFile .*/SSLCertificateFile `$CONFIG_DIR/pubcert.pem`/" `$CONFIG_DIR/openqa-proxy-ssl.conf`
  sed -i "s/SSLCertificateKeyFile .*/SSLCertificateKeyFile `$CONFIG_DIR/privkey.pem`/" `$CONFIG_DIR/openqa-proxy-ssl.conf`

  sed -i '/#ServerName www.example.com:80/a\ServerName openqa.fedorainfracloud.org' /etc/httpd/conf/httpd.conf

else
  echo "Using local SSL/TLS certificates"

  local mojo_resources=$(perl -e 'use Mojolicious; print(Mojolicious->new->home->child("Mojo/IOLoop/resources"))')
  cp "$mojo_resources"/server.crt `$CONFIG_DIR/localhost.crt`
  cp "$mojo_resources"/server.key `$CONFIG_DIR/localhost.key`
  cp "$mojo_resources"/server.crt `$CONFIG_DIR/ca.crt`

  sed -i "s/SSLCertificateFile .*/SSLCertificateFile `$CONFIG_DIR/localhost.crt`/" `$CONFIG_DIR/openqa-proxy-ssl.conf`
  sed -i "s/SSLCertificateKeyFile .*/SSLCertificateKeyFile `$CONFIG_DIR/localhost.key`/" `$CONFIG_DIR/openqa-proxy-ssl.conf`

  sed -i 's/ServerName .*/ServerName www.example.com:80' /etc/httpd/conf/httpd.conf

fi

httpd -DSSL || true

/bin/bash
cleanup