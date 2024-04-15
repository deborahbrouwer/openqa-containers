#!/bin/bash
# If running locally, add values e.g.
# DETACHED=yes ./start-openqa-worker.sh

set -e
IMAGE=localhost/openqa-worker:latest

# The service directory for openqa-workers scripts and logs
if [ -z "${SRV}" ]; then
	SRV='/home/fedora/openqa-containers/openqa-worker'
fi

if [ ! -f "${SRV}/conf/client.conf" ]; then
	echo "Missing ${SRV}/conf/client.conf"
	exit
fi

if [ ! -f "${SRV}/conf/workers.ini" ]; then
	echo "Missing ${SRV}/conf/workers.ini"
	exit
fi

if [[ -z $(podman images --format "{{.Tag}}" $IMAGE) ]]; then
	echo "$IMAGE is missing"
	exit
fi

if [ ! -d "${SRV}/tests" ] && [ ! -L "${SRV}}/tests" ]; then
	mkdir "${SRV}/tests"
fi

if [[ -z "$NUMBER_OF_WORKERS" ]]; then
	NUMBER_OF_WORKERS=10
fi

if [[ "$DETACHED" == "true" ]] || [[ "$DETACHED" == "yes" ]]; then
	detached_arg="-d"
fi

if [ -z $WORKER_CLASS ]; then
	WORKER_CLASS=qemu_x86_64
fi
sed -i "/^WORKER_CLASS/c\WORKER_CLASS=$WORKER_CLASS" ${SRV}/conf/workers.ini
echo "set 'WORKER_CLASS = $WORKER_CLASS'"

# Find all the existing openqa_worker containers on this machine
mapfile -t worker_container_ids < <(podman ps -q --format "{{.Image}} {{.ID}}" | grep "$IMAGE" | awk '{print $2}')

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

OPENQA_WORKER_INSTANCE=1
for i in $(seq 1 $NUMBER_OF_WORKERS); do

	# Make sure that the new OPENQA_WORKER_INSTANCE will be unique
	# by checking all the running containers if any
	while true; do
		available=true
		for container_id in "${worker_container_ids[@]}"; do
			in_use=$(podman exec "$container_id" printenv OPENQA_WORKER_INSTANCE 2>/dev/null)
			if [ "$OPENQA_WORKER_INSTANCE" -eq "$in_use" ]; then
				available=false
				((OPENQA_WORKER_INSTANCE++))
				break;
			fi
		done
		if [ $available = true ]; then
			break
		fi
	done

	DEVELOPER_MODE_PORT=$((OPENQA_WORKER_INSTANCE * 10 + 20003))
	VNC_PORT=$((OPENQA_WORKER_INSTANCE + 5990))
	if [ -n "$vde_arg" ]; then
		vde_arg+=" --name ${BUILD}_${OPENQA_WORKER_INSTANCE} "
	fi

	podman run \
	--rm -i \
	${detached_arg} \
	--name openqa-worker-${OPENQA_WORKER_INSTANCE} \
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
	-v ${SRV}/ovmf:/usr/share/edk2/ovmf:z \
	$IMAGE /init-openqa-worker.sh

	((OPENQA_WORKER_INSTANCE++))
done

