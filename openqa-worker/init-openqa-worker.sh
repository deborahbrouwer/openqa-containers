#!/bin/bash
# Note: this is a modification of upstream openqa/container/worker/run_openqa_worker.sh
set -e

function cleanup() {
	echo "Return ownership of bound directories back to container host."
	chown -R root:root /var/lib/openqa/ /usr/share/openqa/ $vde_switch_path
	exit
}
trap cleanup SIGTERM SIGINT


if [[ -z $OPENQA_WORKER_INSTANCE ]]; then
	OPENQA_WORKER_INSTANCE=1
fi

sed -i "/^WORKER_CLASS/c\WORKER_CLASS=$WORKER_CLASS" /conf/workers.ini

# Replace package configs with custom configs
rm /etc/openqa/client.conf /etc/openqa/workers.ini -rf
ln -s /conf/client.conf /etc/openqa/client.conf
ln -s /conf/workers.ini /etc/openqa/workers.ini

mkdir -p "/var/lib/openqa/pool/${OPENQA_WORKER_INSTANCE}/"
chown -R _openqa-worker /var/lib/openqa/pool/

if [[ -z $qemu_no_kvm ]] || [[ $qemu_no_kvm -eq 0 ]]; then
	if [ -c "/dev/kvm" ] && getent group kvm > /dev/null && lsmod | grep '\<kvm\>' > /dev/null; then
		# Simplified kvm-mknod.sh from https://build.opensuse.org/package/view_file/devel:openQA/openQA_container_worker
		group=$(ls -lhn /dev/kvm | cut -d ' ' -f 4)
		groupmod -g "$group" --non-unique kvm
		usermod -a -G kvm _openqa-worker
	else
		echo "Warning: /dev/kvm doesn't exist or the module isn't loaded. If you want to use KVM, run the container with --device=/dev/kvm"
	fi
fi

chown -R _openqa-worker /var/lib/openqa && \
	chmod -R a+rw /var/lib/openqa

chown -R _openqa-worker /usr/share/openqa/ && \
	chmod -R a+rw /usr/share/openqa/

# Get or update any changes to the fedora tests
test_dir='/var/lib/openqa/share/tests/fedora'
if [ ! -d "$test_dir" ]; then
	su _openqa-worker -c "\
		export dist_name=fedora; \
		export dist=fedora; \
		export giturl='https://pagure.io/fedora-qa/os-autoinst-distri-fedora'; \
		export branch=main; \
		export username='openQA fedora'; \
		export needles_separate=0; \
		export needles_giturl='https://pagure.io/fedora-qa/os-autoinst-distri-fedora'; \
		export needles_branch=main;
		/usr/share/openqa/script/fetchneedles;"
		git config --global --add safe.directory /var/lib/openqa/share/tests/fedora
else
	su _openqa-worker -c "git -C '$test_dir' pull" || true
fi

if [ -n "$VDE" ]; then
	chown -R _openqa-worker $vde_switch_path && \
		chmod -R a+rwx $vde_switch_path

	# temporary fixes to make vde work in containers - need to go upstream
	file_path="/usr/lib/os-autoinst/backend/qemu.pm"
	patch "$file_path" < tmp_vde_changes.diff
fi

qemu-system-x86_64 -S &
kill $!

su _openqa-worker -c "/usr/share/openqa/script/openqa-workercache-daemon" &
su _openqa-worker -c "/usr/share/openqa/script/openqa-worker-cacheservice-minion" &
su _openqa-worker -c "/usr/share/openqa/script/worker --verbose --instance \"$OPENQA_WORKER_INSTANCE\""

cleanup
