#!/bin/bash
set -e
IMAGE=localhost/openqa-worker:latest
if [ -z $WORKER_CLASS ]; then
	WORKER_CLASS=qemu_x86_64
fi
sed -i "/^WORKER_CLASS/c\WORKER_CLASS=$WORKER_CLASS" ${SRV}/conf/workers.ini
echo "set 'WORKER_CLASS = $WORKER_CLASS'"

if [ -n "$vde_arg" ]; then
	vde_arg+=" --name ${BUILD}_${OPENQA_WORKER_INSTANCE} "
fi

if echo "$WORKER_CLASS" | grep -q "vde";  then
	BUILD=$(echo "$WORKER_CLASS" | grep -o 'vde_[^,]*' | cut -d'_' -f2-)
	vde_switch_path="qa-switch_$BUILD"
	echo "worker on $vde_switch_path"
	qemu_host_ip="172.16.2.2"
	dns=$(/usr/bin/resolvectl status | grep Servers | tail -1 | cut -d: -f2- | tr ' ' '\n' | grep -oP '^\d{1,3}(\.\d{1,3}){3}$')
	if ! podman ps --format "{{.Names}}" | grep -q $vde_switch_path; then
		rm /tmp/$vde_switch_path -rf
		mkdir /tmp/$vde_switch_path
		podman run --name $vde_switch_path -i --rm --init --security-opt label=disable \
			-v /tmp/$vde_switch_path:/$vde_switch_path --detach tumbleweed:latest bash -c "
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
	WORKER_HOSTNAME_IP=$(grep 'WORKER_HOSTNAME' ${SRV}/conf/workers.ini | head -1 | awk -F '= ' '{print $2}')
	sed -i "/AUTOINST_URL_HOSTNAME/c\AUTOINST_URL_HOSTNAME=$WORKER_HOSTNAME_IP" ${SRV}/conf/workers.ini

	vde_arg="-v /tmp/$vde_switch_path:/$vde_switch_path \
			-e vde_switch_path=$vde_switch_path "
else
	sed -i "/^AUTOINST_URL_HOSTNAME/c\# AUTOINST_URL_HOSTNAME" ${SRV}/conf/workers.ini
fi

podman run \
	--rm -i -d \
	--name openqa-worker-${OPENQA_WORKER_INSTANCE} --replace \
	--security-opt label=disable \
	--device=/dev/kvm \
	--pids-limit=-1 \
	--network=slirp4netns \
	${vde_arg} \
	-e CONTAINER_HOST=$(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
	-e OPENQA_WORKER_INSTANCE=$OPENQA_WORKER_INSTANCE \
	-e WORKER_CLASS=$WORKER_CLASS \
	-p $DEVELOPER_MODE_PORT:$DEVELOPER_MODE_PORT \
	-p $VNC_PORT:$VNC_PORT \
	-v ${SRV}/conf:/conf:z \
	-v ${SRV}/init-openqa-worker.sh:/init-openqa-worker.sh:z \
	$IMAGE /init-openqa-worker.sh

exit 0
