#!/bin/bash
set -ex

function cleanup() {
    echo "Return ownership of bound directories back to container host."
    chown -R root:root /var/lib/pgsql
    exit
}
trap cleanup SIGTERM SIGINT

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

# keep container running while waiting for connections
tail -f /dev/null

su postgres -c "bash -c '/usr/bin/pg_ctl stop'"

cleanup
