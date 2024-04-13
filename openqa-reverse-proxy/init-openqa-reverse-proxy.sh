#!/bin/bash
set -ex
CONFIG_DIR=/etc/httpd/conf.d
DEFAULT_CONF="/etc/httpd/conf.d/ssl.conf"
SSL_CONF="/conf/openqa-proxy-ssl.conf"
HTTP_CONF="/conf/openqa-proxy.conf"

function cleanup() {
  echo "Return ownership of bound directories back to container host."
  chown -R root:root /etc/httpd/logs
  exit
}

trap cleanup SIGTERM SIGINT


dnf install -y mod_md perl perl-Mojolicious procps-ng mod_proxy_html
ln -s /etc/httpd/conf.modules.d/00-base.conf /etc/httpd/conf.modules.d/00-base.load
ln -s /etc/httpd/conf.modules.d/00-ssl.conf /etc/httpd/conf.modules.d/00-ssl.load
/usr/libexec/httpd-ssl-gencerts

# create symlinks for the config files
ln -s $SSL_CONF $CONFIG_DIR/openqa-proxy-ssl.conf
ln -s $HTTP_CONF $CONFIG_DIR/openqa-proxy.conf

# make sure the configs have the correct proxy destination
sed -i "s|ProxyPass .*|ProxyPass / http://$PROXY_DST:8080/ keepalive=On|g" $SSL_CONF
sed -i "s|ProxyPass .*|ProxyPass / http://$PROXY_DST:8080/ keepalive=On|g" $HTTP_CONF
sed -i "s|ProxyPassReverse .*|ProxyPassReverse / http://$PROXY_DST:8080/ |g" $SSL_CONF
sed -i "s|ProxyPassReverse .*|ProxyPassReverse / http://$PROXY_DST:8080/ |g" $HTTP_CONF

# Production configuration
if [ -f "/conf/privkey.pem" ]; then
  echo "Using production SSL/TLS certificates"

  # Move the certs into the config dir
  ln -s /conf/pubcert.pem $CONFIG_DIR/pubcert.pem
  ln -s /conf/privkey.pem $CONFIG_DIR/privkey.pem

  # Edit the configs
  sed -i "s|SSLCertificateFile .*|SSLCertificateFile $CONFIG_DIR/pubcert.pem|" $SSL_CONF
  sed -i "s|SSLCertificateKeyFile .*|SSLCertificateKeyFile $CONFIG_DIR/privkey.pem|" $SSL_CONF

  # There is no separate certificate chain file so ignore this
  sed -i "s|SSLCertificateChainFile .*|# SSLCertificateKeyFile |" $SSL_CONF

  # Just in case make sure this is correct in the default configs too
  sed -i "s|SSLCertificateFile .*|SSLCertificateFile $CONFIG_DIR/pubcert.pem|" $DEFAULT_CONF
  sed -i "s|SSLCertificateKeyFile .*|SSLCertificateKeyFile $CONFIG_DIR/privkey.pem|" $DEFAULT_CONF

else
# local configuration
  echo "Using local SSL/TLS certificates"

  mojo_resources=$(perl -e 'use Mojolicious; print(Mojolicious->new->home->child("Mojo/IOLoop/resources"))')
  cp "$mojo_resources"/server.crt $CONFIG_DIR/localhost.crt
  cp "$mojo_resources"/server.key $CONFIG_DIR/localhost.key
  cp "$mojo_resources"/server.crt $CONFIG_DIR/ca.crt

  sed -i "s|SSLCertificateFile .*|SSLCertificateFile $CONFIG_DIR/localhost.crt|" $SSL_CONF
  sed -i "s|SSLCertificateKeyFile .*|SSLCertificateKeyFile $CONFIG_DIR/localhost.key|" $SSL_CONF
  sed -i "s|.*SSLCertificateChainFile .*|SSLCertificateChainFile $CONFIG_DIR/ca.crt|" $SSL_CONF

  # Just in case make sure this is correct in the default configs too
  sed -i "s|SSLCertificateFile .*|SSLCertificateFile $CONFIG_DIR/localhost.crt|" $DEFAULT_CONF
  sed -i "s|SSLCertificateKeyFile .*|SSLCertificateKeyFile $CONFIG_DIR/localhost.key|" $DEFAULT_CONF

fi

# Stop the default config from interfering
sed -i "s|SSLEngine .*|SSLEngine off|" $DEFAULT_CONF
sed -i "s|Listen .*|# Listen|" $DEFAULT_CONF

# Set the server name
sed -i "s|.*ServerName.*|ServerName $SERVER_NAME|" /etc/httpd/conf/httpd.conf
sed -i "s|.*ServerName.*|ServerName $SERVER_NAME|" $SSL_CONF
sed -i "s|.*ServerName.*|ServerName $SERVER_NAME|" $HTTP_CONF

httpd -DSSL || true

# keep container running even if httpd fails
tail -f /dev/null

cleanup