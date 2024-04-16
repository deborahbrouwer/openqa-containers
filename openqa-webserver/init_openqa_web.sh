#!/bin/bash
# Note: this is a modification of upstream openqa/container/webui/run_openqa.sh
set -e

function cleanup() {
  echo "Return ownership of bound directories back to container host."
  chown -R root:root /var/lib/pgsql /var/lib/openqa/ /usr/share/openqa/ /etc/httpd/logs
  exit
}
trap cleanup SIGTERM SIGINT

function configure_openqa() {
  rm -rf /etc/openqa/openqa.ini
  ln -s /conf/openqa.ini /etc/openqa/openqa.ini

  rm -rf /etc/openqa/client.conf
  ln -s /conf/client.conf /etc/openqa/client.conf

  # This config includes /etc/httpd/conf.d/openqa-common.inc which sets the openQA Document Root for web
  ln -s /conf/openqa.conf /etc/httpd/conf.d/openqa.conf
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
  httpd -DNOSSL || true
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
