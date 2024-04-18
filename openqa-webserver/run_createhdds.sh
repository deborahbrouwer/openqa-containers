#!/bin/bash
# sudo dnf install -y python3-libguestfs  libvirt-devel virt-install fedfind vim git  
# rsync -avz --sparse fedora@<sourceip>:<source dir> <dest dir>

set -e

run_createhdds() {
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
}

run_createhdds
