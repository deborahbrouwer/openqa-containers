#!/bin/bash
set -e

usage() {
		echo -e "\nUsage: $0 [Options]\n"
		echo "Options:"
		echo "	-b	[openqa | openqa_worker] Build the container image."
		echo "	-c	Get and run createhdds to provide images unavailable through fedoraproject.org."
		echo "	-h	Show this help message."
		exit 1
}

tag_old_images() {
	# Keep the previous image and retag it as "old" and delete any older images
	while IFS= read -r line; do
		echo "$line"
		image_id=$(echo "$line" | awk '{print $3}')
		tag=$(echo "$line" | awk '{print $2}')
		if [ "$tag" == "latest" ]; then
				podman tag "${REPOSITORY}:latest" "${REPOSITORY}:old"
		else
				podman rmi $image_id || true
		fi
	done < <(podman images --filter "reference=${REPOSITORY}" --format "{{.Repository}} {{.Tag}} {{.ID}} {{.CreatedAt}}")
}

build_openqa_image() {
	REPOSITORY=openqa
	tag_old_images
	podman build --no-cache -t $REPOSITORY .
}

build_openqa_worker_image() {
	REPOSITORY=openqa_worker
	tag_old_images
	cd openqa-worker
	podman build --no-cache -t $REPOSITORY .
    exit
}

get_openqa_webui_image_id() {
	OPENQA_WEBUI_IMAGE_ID=$(podman images --filter "reference=${REPOSITORY}" --format "{{.Repository}} {{.Tag}} {{.ID}}" | awk '$2 == "latest" {print $3}')
}

run_createhdds() {
	cd openqa-webserver
	if [ ! -d "$PWD/hdd" ] && [ ! -L "$PWD/hdd" ]; then
		mkdir "$PWD/hdd"
	fi
	if [ ! -d "$PWD/createhdds" ] && [ ! -L "$PWD/createhdds" ]; then
		git clone https://pagure.io/fedora-qa/createhdds
	fi

	cd createhdds
	# createhdds must run in the background so that it can be interrupted by this shell script
	./createhdds.py all -c > temp.log 2>&1 &

	# Exit if there are any errors e.g. missing dependencies preventing createhdds from running.
	sleep 1
	if grep -q "Traceback" temp.log; then
		cat temp.log
		exit 1;
	fi
	PID=$!

	# While createhdds is running, check if it is hanging and if so, then
	# copy the temp file, force createhdds to stop, and then restart it
	while kill -0 $PID 2>/dev/null; do
		FILE_NAME=$(grep "qcow2" temp.log | head -n 1 | sed -n 's/.*\(disk_[^ ]*.qcow2\).*/\1/p')
		sleep 5
		if [[ -f "$FILE_NAME.tmp" ]]; then
			echo "-->copying $FILE_NAME.tmp"
			cp "$FILE_NAME.tmp" $FILE_NAME
			kill -SIGINT $PID
			rm temp.log
			./createhdds.py all -c > temp.log 2>&1 &
			PID=$!
		fi
	done
	rm temp.log

	# then move the file to hdd/
	# then change the SELinux context (ls -lZ) so that the image can be accessed in the container
	for file in *; do
		if [[ "$file" == *.qcow2 ]] || [[ "$file" == *.img ]]; then
			if [ ! -f "../hdd/$file" ]; then
				cp "$file" ../hdd/
				chcon system_u:object_r:container_file_t:s0 ../hdd/$file;
				chmod a+rw ../hdd/$file;
				files_copied=1
			fi
		fi
	done
	cd ..

	if [ "$files_copied" ] && [ "$(podman ps -q --format "{{.Image}} {{.ID}}" | grep "$REPOSITORY")" ]; then
		echo -e "\n--> Warning images were copied to hdd/ while the web UI container is running."
		echo "--> Restart the web UI container to access these images."
	fi

}

while getopts ":b:ch" opt; do
	case ${opt} in
		b )
			case $OPTARG in
				openqa)
					build_openqa_image
					;;
				openqa_worker)
					build_openqa_worker_image
					;;
				*)
					echo "Invalid argument: $OPTARG" >&2
					exit 1
					;;
			esac
			exit
			;;
		c )
			run_createhdds
			exit
			;;
		h )
			usage
			;;
		\? )
			echo "Invalid option: $OPTARG" 1>&2
			usage
			;;
		: )
			echo "Invalid option: $OPTARG requires an argument" 1>&2
			usage
			;;
	esac
done

if [ $(($# - ${OPTIND:-0} + 1)) -gt 0 ]; then
	echo "Unsupported arguments. Exiting."
	usage
	exit 1
fi
