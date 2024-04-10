#!/bin/bash
# If running locally, add values e.g.
# SRV='/home/fedora/openqa-containers/openqa-webserver' DETACHED=yes LOCAL_PORTS=yes ./start-openqa-webserver.sh

set -e
IMAGE=localhost/openqa-webserver:latest

if [ ! -d "${SRV}/hdd" ] && [ ! -L "${SRV}}/hdd" ]; then
	mkdir "${SRV}/hdd"
fi

if [ ! -d "${SRV}/iso" ] && [ ! -L "${SRV}}/iso" ]; then
	mkdir "${SRV}/iso"
fi

cp "${SRV}/cloudinit.iso" "${SRV}/iso/"

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

ports_arg="-p 80:80 -p 443:443"
if [[ "$LOCAL_PORTS" == "true" ]] || [[ "$LOCAL_PORTS" == "yes" ]]; then
    ports_arg="-p 8080:80 -p 1443:443"
fi

podman run --rm -i --name openqa-webserver \
	${ports_arg} \
	${detached_arg} \
	--network=slirp4netns \
	-e GENERATE_CERTS=$GENERATE_CERTS \
	-v ${SRV}/hdd:/var/lib/openqa/share/factory/hdd:z \
	-v ${SRV}/iso:/var/lib/openqa/share/factory/iso:z \
	-v ${SRV}/data:/var/lib/pgsql/data/:z \
	-v ${SRV}/conf:/conf/:z \
	-v ${SRV}/init_openqa_web.sh:/init_openqa_web.sh:z \
	$IMAGE /init_openqa_web.sh

