#!/bin/bash
set -e
REPOSITORY=openqa-worker

# Find all the existing openqa_worker containers on this machine
mapfile -t worker_container_ids < <(podman ps -q --format "{{.Image}} {{.ID}}" | grep "$REPOSITORY" | awk '{print $2}')

# Stop all the workers gracefully, by giving them the opportunity to tell the scheduler
# that they are going offline. Otherwise scheduler will keep trying to send tests to non-existent workers.

if [ -z $WORKER_CLASS ]; then
	for container_id in "${worker_container_ids[@]}"; do
		process_id=$(podman exec "$container_id" pgrep -f 'perl /usr/share/openqa/script/worker' | head -n 1)
		podman exec -it $container_id sh -c "kill $process_id"
		echo "killed $container_id"
	done
	exit
fi

# if a WORKER_CLASS is set, then stop only those workers
BUILD=$(echo "$WORKER_CLASS" | grep -o 'vde_[^,]*' | cut -d'_' -f2-)
matching_container_ids=($(podman ps -a --format "{{.Names}}" | grep "$BUILD" | grep -v "qa-switch"))
for container_id in "${matching_container_ids[@]}"; do
	actual_container_id=$(podman ps -a --filter "name=$container_id" --format "{{.ID}}")
	process_id=$(podman exec "$actual_container_id" pgrep -f 'perl /usr/share/openqa/script/worker' | head -n 1)
	podman exec -it "$actual_container_id" sh -c "kill $process_id"
	echo "killed $actual_container_id"
done
