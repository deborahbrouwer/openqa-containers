#!/bin/bash
# sudo dnf install -y python3-libguestfs  libvirt-devel virt-install fedfind vim git edk2-ovmf
# rsync -avz --sparse fedora@<sourceip>:/home/fedora/openqa-containers/createhdds <dest dir>

set -e
SRV='/home/fedora/openqa-containers'

if [ ! -d "$SRV/createhdds" ]; then
	git clone https://pagure.io/fedora-qa/createhdds "$SRV/createhdds"
else
	git -C "$SRV/createhdds" pull || true
fi

# Images are created in the directory from which it's run
cd "$SRV/createhdds"
./createhdds.py all
