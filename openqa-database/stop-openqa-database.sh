#!/bin/bash
set -ex

if [ -z "${DATADIR}" ]; then
	DATADIR='/var/lib/pgsql/data/'
fi

/usr/bin/podman exec openqa-database /bin/bash -c 'su postgres -c "/usr/bin/pg_ctl -D '${DATADIR}' stop -m smart"'

# Return ownership of bound directories back to container host
/usr/bin/podman exec openqa-database /bin/bash -c 'chown -R root:root /var/lib/pgsql'

/usr/bin/podman exec openqa-database /bin/bash -c 'pkill -f tail'
