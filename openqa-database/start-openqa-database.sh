#!/bin/bash
# If running locally, define values e.g.
# DETACHED=yes /home/fedora/openqa-containers/openqa-database/start-openqa-database.sh

set -e
IMAGE=localhost/openqa-database:latest

if [[ -z $(podman images --format "{{.Tag}}" $IMAGE) ]]; then
    echo "$IMAGE is missing"
	exit
fi

if [ -z "${SRV}" ]; then
	SRV='/home/fedora/openqa-containers/openqa-database'
fi

if [ -z "${DATADIR}" ]; then
	DATADIR='/var/lib/pgsql/data/'
fi

if [ ! -d "${SRV}/data" ]; then
	mkdir -p "${SRV}/data"
fi

if [[ "$DETACHED" == "true" ]] || [[ "$DETACHED" == "yes" ]]; then
    detached_arg="-d"
fi

podman run --rm -i --name openqa-database \
	--user=root \
	${detached_arg} \
	--network=slirp4netns \
	-p 5432:5432 \
	-e DATADIR:$DATADIR \
	-v ${SRV}/data:/var/lib/pgsql/data/:z \
	-v ${SRV}/init_openqa_database.sh:/init_openqa_database.sh:z \
	$IMAGE /init_openqa_database.sh
