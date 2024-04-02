#!/bin/bash
set -e
REPOSITORY=openqa-webserver

usage() {
		echo -e "\nUsage: $0 [Options]\n"
		echo "Options:"
		echo "	-h	Show this help message."
		echo "	-d	For debugging: specify a local path to openQA repository."
		echo "	-f	For debugging: specify a local path to os-autoinst-distri-fedora"
		echo "	-s	For debugging: specify a local path to fedora_openqa"
		exit 1
}

cd $(dirname "$0")

while getopts ":hd:f:s:" opt; do
	case ${opt} in
		b )
			build_openqa_webui_image
			exit
			;;
		c )
			run_createhdds
			exit
			;;
		h )
			usage
			;;
		d )
			openQA_debug_path=$OPTARG
			;;
		f )
			os_autoinst_distri_fedora_path=$OPTARG
			;;
		s )
			fedora_openqa_path=$OPTARG
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

# https://github.com/os-autoinst/openQA.git
if [ -n "$openQA_debug_path"  ]; then
	if [[ $openQA_debug_path == */ ]]; then
			openQA_debug_path=${openQA_debug_path%/}
	fi
	openqa_debug_arg="-v $openQA_debug_path/script/:/usr/share/openqa/script/:z \
		-v $openQA_debug_path/lib/:/usr/share/openqa/lib/:z \
		-v $openQA_debug_path/assets/:/usr/share/openqa/assets/:z "
fi

# https://pagure.io/fedora-qa/os-autoinst-distri-fedora
if [ -n "$os_autoinst_distri_fedora_path" ]; then
	if [[ $os_autoinst_distri_fedora_path == */ ]]; then
		os_autoinst_distri_fedora_path=${os_autoinst_distri_fedora_path%/}
	fi
	os_autoinst_distri_fedora_arg="-v $os_autoinst_distri_fedora_path/:/var/lib/openqa/share/tests/fedora/:z "
else
	if [ ! -d "$PWD/tests" ] && [ ! -L "$PWD/tests" ]; then
		mkdir "$PWD/tests"
	fi
	os_autoinst_distri_fedora_arg="-v $PWD/tests:/var/lib/openqa/share/tests:z "
fi

# https://pagure.io/fedora-qa/fedora_openqa.git
if [ -n "$fedora_openqa_path" ]; then
	if [[ $fedora_openqa_path == */ ]]; then
		fedora_openqa_path=${fedora_openqa_path%/}
	fi
	fedora_openqa_arg="-v $fedora_openqa_path/:/fedora_openqa:z "
else
	if [ ! -d "$PWD/fedora_openqa" ] && [ ! -L "$PWD/fedora_openqa" ]; then
		mkdir "$PWD/fedora_openqa"
	fi
	fedora_openqa_arg="-v $PWD/fedora_openqa:/fedora_openqa:z "
fi

podman run --rm -it --name openqa-webserver-debug \
	-p 8080:80 -p 1443:443 \
	--network=slirp4netns \
	-v $PWD/hdd:/var/lib/openqa/share/factory/hdd:z \
	-v $PWD/iso:/var/lib/openqa/share/factory/iso:z \
	-v $PWD/data:/var/lib/pgsql/data/:z \
	-v $PWD/conf:/conf/:z \
	-v $PWD/init_openqa_web.sh:/init_openqa_web.sh:z \
	${os_autoinst_distri_fedora_arg} \
	${openqa_debug_arg} \
	${fedora_openqa_arg} \
	localhost/openqa:latest /init_openqa_web.sh
