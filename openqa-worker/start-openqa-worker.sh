#!/bin/bash
set -ex

# The service directory for openqa-workers scripts and logs
if [ -z "${SRV}" ]; then
	SRV='/home/fedora/openqa-containers/openqa-worker'
fi

INSTANCE_NAME=$1
WORKER_CLASS="${INSTANCE_NAME%_*}"
OPENQA_WORKER_INSTANCE="${INSTANCE_NAME##*_}"
DEVELOPER_MODE_PORT=$((OPENQA_WORKER_INSTANCE * 10 + 20003))
VNC_PORT=$((OPENQA_WORKER_INSTANCE + 5990))

podman run \
	--rm -i \
	--name openqa-worker-${OPENQA_WORKER_INSTANCE} --replace \
	--security-opt label=disable \
	--device=/dev/kvm \
	--pids-limit=-1 \
	--network=slirp4netns \
	-e OPENQA_WORKER_INSTANCE=$OPENQA_WORKER_INSTANCE \
	-e WORKER_CLASS=$WORKER_CLASS \
	-p $DEVELOPER_MODE_PORT:$DEVELOPER_MODE_PORT \
	-p $VNC_PORT:$VNC_PORT \
	-v ${SRV}/conf:/conf:z \
	-v ${SRV}/init-openqa-worker.sh:/init-openqa-worker.sh:z \
	localhost/openqa-worker:latest /init-openqa-worker.sh

exit 0
