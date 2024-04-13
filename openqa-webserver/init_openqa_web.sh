#!/bin/bash
# Note: this is a modification of upstream openqa/container/webui/run_openqa.sh
set -e

function cleanup() {
  echo "Return ownership of bound directories back to container host."
  chown -R root:root /var/lib/pgsql /var/lib/openqa/ /usr/share/openqa/
  exit
}
trap cleanup SIGTERM SIGINT

function configure_openqa() {
  if [ -f "/conf/openqa.ini" ]; then
    rm -rf /etc/openqa/openqa.ini
    ln -s /conf/openqa.ini /etc/openqa/openqa.ini
  fi

  if [ -f "/conf/client.conf" ]; then
    rm -rf /etc/openqa/client.conf
    ln -s /conf/client.conf /etc/openqa/client.conf
  fi
}

function configure_apache() {
  if [ -f "/conf/privkey.pem" ]; then
    # Production configuration
    echo "Using production SSL/TLS certificates"

    ln -s /conf/pubcert.pem /etc/pki/tls/certs/pubcert.pem
    ln -s /conf/privkey.pem /etc/pki/tls/private/privkey.pem

    sed -i '/#ServerName www.example.com:80/a\ServerName openqa.fedorainfracloud.org' /etc/httpd/conf/httpd.conf

    # Use the configs that include mod_md
    ln -s /conf/openqa-ssl.conf /etc/httpd/conf.d/openqa-ssl.conf
    ln -s /conf/openqa.conf /etc/httpd/conf.d/openqa.conf
  else
    # Local configuration
    echo "Using local SSL/TLS certificates"

    cp /etc/httpd/conf.d/openqa.conf.template /etc/httpd/conf.d/openqa.conf
    cp /etc/httpd/conf.d/openqa-ssl.conf.template /etc/httpd/conf.d/openqa-ssl.conf
    sed -i 's/^\s*#SSLCertificateFile/SSLCertificateFile/' /etc/httpd/conf.d/openqa-ssl.conf
    sed -i 's/^\s*#SSLCertificateKeyFile/SSLCertificateKeyFile/' /etc/httpd/conf.d/openqa-ssl.conf
    sed -i 's/^\s*#SSLCertificateChainFile/SSLCertificateChainFile/' /etc/httpd/conf.d/openqa-ssl.conf

    local mojo_resources=$(perl -e 'use Mojolicious; print(Mojolicious->new->home->child("Mojo/IOLoop/resources"))')
    cp "$mojo_resources"/server.crt /etc/pki/tls/certs/openqa.crt
    cp "$mojo_resources"/server.key /etc/pki/tls/private/openqa.key
    cp "$mojo_resources"/server.crt /etc/pki/tls/certs/ca.crt
  fi

}

function upgradedb() {
  echo "Waiting for DB creation"
  while ! su geekotest -c 'PGPASSWORD=openqa psql -h db -U openqa --list | grep -qe openqa'; do sleep .1; done
  su geekotest -c '/usr/share/openqa/script/upgradedb --upgrade_database'
}

function start_services() {
  su geekotest -c /usr/share/openqa/script/openqa-scheduler-daemon &
  su geekotest -c /usr/share/openqa/script/openqa-websockets-daemon &
  su geekotest -c /usr/share/openqa/script/openqa-gru &
  su geekotest -c /usr/share/openqa/script/openqa-livehandler-daemon &
  # if apache server fails look in /etc/httpd/logs
  httpd -DSSL || true
  su geekotest -c /usr/share/openqa/script/openqa-webui-daemon
}

function start_database() {
  mkdir -p /var/run/postgresql
  chown -R postgres:postgres /var/lib/pgsql /var/run/postgresql && \
    find /var/lib/pgsql/data -type d -exec chmod 750 {} + && \
    find /var/lib/pgsql/data -type f -exec chmod 750 {} +

  chmod ug+r /var/lib/pgsql/data

  DATADIR="/var/lib/pgsql/data/"

  if [ -z "$(ls -A $DATADIR)" ]; then
    echo "Initializing PostgreSQL"
    su postgres -c "bash -c '/usr/bin/initdb ${DATADIR}'"
    if [ $? -ne 0 ]; then
      echo "Initialization failed."
      exit 1
    fi
  fi
  su postgres -c "bash -c '/usr/bin/pg_ctl -s -D ${DATADIR} start'"
  su postgres -c '/usr/bin/openqa-setup-db'

  # TODO: use upgradedb script here if necessary for real data
}

usermod --shell /bin/sh geekotest

# TODO when quay.io/fedora/fedora images starts using Fedora 40, this can be removed
dnf -y upgrade --enablerepo=updates-testing --refresh --advisory=FEDORA-2024-b44061e715

configure_openqa
configure_apache

chown -R geekotest /usr/share/openqa /var/lib/openqa && \
	chmod -R a+rw /usr/share/openqa /var/lib/openqa

# Replace bullet character with unicode since it sometimes interferes with the webpage display
sed -i 's/content: "•";/content: "\\2022";/' /usr/share/openqa/assets/stylesheets/overview.scss

# Get or update any changes to the fedora tests
test_dir='/var/lib/openqa/share/tests/fedora'
if [ ! -d "$test_dir" ]; then
  su geekotest -c "\
    export dist_name=fedora; \
    export dist=fedora; \
    export giturl='https://pagure.io/fedora-qa/os-autoinst-distri-fedora'; \
    export branch=main; \
    export username='openQA fedora'; \
    export needles_separate=0; \
    export needles_giturl='https://pagure.io/fedora-qa/os-autoinst-distri-fedora'; \
    export needles_branch=main;
    /usr/share/openqa/script/fetchneedles; \
    git config --global --add safe.directory /var/lib/openqa/share/tests/fedora"
else
  su geekotest -d "git config --global --add safe.directory '$test_dir'" || true
  su geekotest -c "git -C '$test_dir' pull" || true
fi

chown -R geekotest /usr/share/openqa /var/lib/openqa && \
	chmod -R a+rw /usr/share/openqa /var/lib/openqa

start_database
start_services

cleanup
