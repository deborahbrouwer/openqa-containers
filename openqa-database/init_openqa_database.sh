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

if [ -z "${DATADIR}" ]; then
	DATADIR='/var/lib/pgsql/data/'
fi

if [ -z "$(ls -A $DATADIR)" ]; then
	echo "Initializing PostgreSQL"
	su postgres -c "bash -c '/usr/bin/initdb ${DATADIR}'"
	if [ $? -ne 0 ]; then
		echo "Initialization failed."
		exit 1
	fi

	# listen from all ips
	# this works as long as the database is on the same host as the webserver
	# more configuration will be needed if the database has to expose public ports
	# /var/lib/pgsql/data/postgresql.conf
	sed -i "/# - Connection Settings -/a listen_addresses = '*'" /var/lib/pgsql/data/postgresql.conf

	# accept all incoming connections
	echo "# IPv4 openqa:" | sudo tee -a /var/lib/pgsql/data/pg_hba.conf
	echo "host	all	all	0.0.0.0/0	trust" | sudo tee -a /var/lib/pgsql/data/pg_hba.conf
fi

su postgres -c "bash -c '/usr/bin/pg_ctl -s -D ${DATADIR} start'"
su postgres -c '/usr/bin/openqa-setup-db'

# keep container running while waiting for connections
tail -f /dev/null

su postgres -c "bash -c '/usr/bin/pg_ctl -D ${DATADIR} stop'"

cleanup
