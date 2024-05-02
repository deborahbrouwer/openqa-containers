#!/bin/bash
# ./start-openqa-worker.sh Fedora-CoreOS-40.20240501.20.0_5
# ./start-openqa-worker.sh qemu_x86_64_2
set -ex

if [ -z "${SRV}" ]; then
	SRV='/home/fedora/openqa-containers/openqa-worker'
fi

INSTANCE_NAME=$1
WORKER_CLASS="${INSTANCE_NAME%_*}"
OPENQA_WORKER_INSTANCE="${INSTANCE_NAME##*_}"
DEVELOPER_MODE_PORT=$((OPENQA_WORKER_INSTANCE * 10 + 20003))
VNC_PORT=$((OPENQA_WORKER_INSTANCE + 5990))

if [[ -z $WORKER_CLASS ]]; then
	WORKER_CLASS=qemu_x86_64
fi

if [ "$WORKER_CLASS" != "qemu_x86_64" ]; then
	vde_switch_path="qa-switch_$WORKER_CLASS"

	if ! podman ps --format "{{.Names}}" | grep -q $vde_switch_path; then

		rm /tmp/$vde_switch_path -rf
		mkdir /tmp/$vde_switch_path

		qemu_host_ip="172.16.2.2"
		dns=$(resolvectl status | awk '/Current DNS Server:/ {print $4}')

		podman run --name $vde_switch_path -i -d --rm --init --security-opt label=disable \
			-v /tmp/$vde_switch_path:/$vde_switch_path \
			registry.opensuse.org/opensuse/tumbleweed /bin/bash -c "
				set -uex
				zypper update -y
				zypper in -y vde2 vde2-slirp
				vde_switch --sock /$vde_switch_path/vde.ctl --daemon
				slirpvde --sock /$vde_switch_path/vde.ctl --host $qemu_host_ip --dns $dns
			"
		while [ ! -e /tmp/$vde_switch_path/vde.ctl ]; do
			sleep 1
		done

		if ! podman ps --format "{{.Names}}" | grep -q $vde_switch_path; then
			echo "Error creating vde switch. Exit without starting worker."
			exit
		fi
	fi

	# AUTOINST_URL_HOSTNAME is used when a test running in qemu wants to upload logs to its host
	# For netdev = user, the default 172.16.2.2 is the container so this works fine
	# But for netdev = vde, 172.16.2.2 is the gateway of the switch so we have
	# to set AUTOINST_URL_HOSTNAME to the WORKER_HOSTNAME and come back to the container through its open port
	# See os-autoinst/testapi.pm autoinst_url() and upload_logs()
	# WORKER_HOSTNAME_IP=$(grep 'WORKER_HOSTNAME' ${SRV}/conf/workers.ini | head -1 | awk -F '= ' '{print $2}')
	# sed -i "/AUTOINST_URL_HOSTNAME/c\AUTOINST_URL_HOSTNAME=$WORKER_HOSTNAME_IP" ${SRV}/conf/workers.ini

	WORKER_CLASS+=",qemu_x86_64"
	vde_arg="-v /tmp/$vde_switch_path:/$vde_switch_path \
			-e vde_switch_path=$vde_switch_path \
			--device=/dev/net/tun \
			--privileged \
			-e VDE=$VDE"
fi

podman run \
	--rm -i \
	--name openqa-worker-$OPENQA_WORKER_INSTANCE --replace \
	--hostname=$(hostname) \
	--security-opt label=disable \
	--device=/dev/kvm \
	--pids-limit=-1 \
	--network=slirp4netns \
	${vde_arg} \
	-e OPENQA_WORKER_INSTANCE=$OPENQA_WORKER_INSTANCE \
	-e WORKER_CLASS=$WORKER_CLASS \
	-p $DEVELOPER_MODE_PORT:$DEVELOPER_MODE_PORT \
	-p $VNC_PORT:$VNC_PORT \
	-v ${SRV}/conf:/conf:z \
	-v ${SRV}/tests/fedora:/var/lib/openqa/share/tests/fedora:z \
	-v ${SRV}/init-openqa-worker.sh:/init-openqa-worker.sh:z \
	localhost/openqa-worker:latest /init-openqa-worker.sh

exit 0
