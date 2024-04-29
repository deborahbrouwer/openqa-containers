#!/bin/bash

# Find all the existing openqa_worker containers on this machine
mapfile -t worker_container_ids < <(podman ps -q --format "{{.Image}} {{.ID}}" | grep "$IMAGE" | awk '{print $2}')

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
