#!/bin/bash
# If running locally, define values e.g.
# SRV='/home/fedora/openqa-containers/openqa-webserver' DETACHED=yes /home/fedora/openqa-containers/openqa-webserver/start-openqa-webserver.sh

set -e
IMAGE=localhost/openqa-webserver:latest

if [ ! -f "${SRV}/conf/openqa.ini" ]; then
	echo "Missing ${SRV}/conf/openqa.ini"
    exit
fi

if [ ! -f "${SRV}/conf/client.conf" ]; then
	echo "Missing ${SRV}/conf/client.conf"
    exit
fi

if [ ! -d "${SRV}/hdd/fixed" ] && [ ! -L "${SRV}}/hdd/fixed" ]; then
	mkdir -p "${SRV}/hdd/fixed"
fi

if [ ! -d "${SRV}/iso/fixed" ] && [ ! -L "${SRV}}/iso/fixed" ]; then
	mkdir -p "${SRV}/iso/fixed"
fi

cp "${SRV}/cloudinit.iso" "${SRV}/iso/fixed"

if [ ! -d "${SRV}/logs" ] && [ ! -L "${SRV}}/logs" ]; then
	mkdir -p "${SRV}/logs"
fi

if [ ! -d "${SRV}/testresults" ] && [ ! -L "${SRV}}/testresults" ]; then
	mkdir -p "${SRV}/testresults"
fi

if [ ! -d "${SRV}/images" ] && [ ! -L "${SRV}}/images" ]; then
	mkdir -p "${SRV}/images"
fi

if [[ -z $(podman images --format "{{.Tag}}" $IMAGE) ]]; then
    echo "$IMAGE is missing"
	exit
fi

if [[ "$DETACHED" == "true" ]] || [[ "$DETACHED" == "yes" ]]; then
    detached_arg="-d"
fi

podman run --rm -i --name openqa-webserver \
	-p 8080:80 \
	${detached_arg} \
	--network=slirp4netns \
	-v ${SRV}/hdd:/var/lib/openqa/share/factory/hdd:z \
	-v ${SRV}/iso:/var/lib/openqa/share/factory/iso:z \
	-v ${SRV}/conf:/conf/:z \
	-v ${SRV}/logs:/etc/httpd/logs/:z \
	-v ${SRV}/testresults:/var/lib/openqa/testresults/:z \
	-v ${SRV}/images:/var/lib/openqa/images/:z \
	-v ${SRV}/init_openqa_web.sh:/init_openqa_web.sh:z \
	$IMAGE /init_openqa_web.sh

