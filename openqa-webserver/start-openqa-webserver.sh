#!/bin/bash
# If running locally, define values e.g.
# SRV='/home/fedora/openqa-containers/openqa-webserver' DETACHED=yes ./start-openqa-webserver.sh

set -e
IMAGE=localhost/openqa-webserver:latest

if [ ! -d "${SRV}/hdd/fixed" ] && [ ! -L "${SRV}}/hdd/fixed" ]; then
	mkdir -p "${SRV}/hdd/fixed"
fi

if [ ! -d "${SRV}/iso/fixed" ] && [ ! -L "${SRV}}/iso/fixed" ]; then
	mkdir -p "${SRV}/iso/fixed"
fi

cp "${SRV}/cloudinit.iso" "${SRV}/iso/fixed"

if [ ! -d "${SRV}/data" ] && [ ! -L "${SRV}}/data" ]; then
	echo "Missing ${SRV}/data"
    exit
fi

if [ ! -f "${SRV}/conf/client.conf" ]; then
	echo "Missing ${SRV}/conf/client.conf"
    exit
fi

if [[ -z $(podman images --format "{{.Tag}}" $IMAGE) ]]; then
    echo "$IMAGE is missing"
	exit
fi

if [[ "$DETACHED" == "true" ]] || [[ "$DETACHED" == "yes" ]]; then
    detached_arg="-d"
fi

podman run --rm -i --name openqa-webserver \
	-p 8080:80 -p 1443:443 \
	${detached_arg} \
	--network=slirp4netns \
	-v ${SRV}/hdd:/var/lib/openqa/share/factory/hdd:z \
	-v ${SRV}/iso:/var/lib/openqa/share/factory/iso:z \
	-v ${SRV}/data:/var/lib/pgsql/data/:z \
	-v ${SRV}/conf:/conf/:z \
	-v ${SRV}/init_openqa_web.sh:/init_openqa_web.sh:z \
	$IMAGE /init_openqa_web.sh

