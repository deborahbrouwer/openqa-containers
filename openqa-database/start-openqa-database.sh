#!/bin/bash
# If running locally, define values e.g.
# SRV='/home/fedora/openqa-containers/openqa-database' DETACHED=yes /home/fedora/openqa-containers/openqa-database/start-openqa-database.sh

set -e
IMAGE=localhost/openqa-database:latest

if [ ! -d "${SRV}/data" ]; then
	mkdir -p "${SRV}/data"
fi

if [ ! -d "${SRV}/logs" ] && [ ! -L "${SRV}}/logs" ]; then
	mkdir -p "${SRV}/logs"
fi

if [[ -z $(podman images --format "{{.Tag}}" $IMAGE) ]]; then
    echo "$IMAGE is missing"
	exit
fi

if [[ "$DETACHED" == "true" ]] || [[ "$DETACHED" == "yes" ]]; then
    detached_arg="-d"
fi

podman run --rm -i --name openqa-database \
	--user=root \
	${detached_arg} \
	--network=slirp4netns \
	-p 5432:5432 \
	-v ${SRV}/data:/var/lib/pgsql/data/:z \
	-v ${SRV}/conf:/conf/:z \
	-v ${SRV}/init_openqa_database.sh:/init_openqa_database.sh:z \
	$IMAGE /init_openqa_database.sh

