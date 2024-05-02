FROM opensuse/tumbleweed
LABEL title="openqa-worker"

COPY ovmf /usr/share/edk2/ovmf
COPY tmp_vde_changes.diff /

RUN zypper in -yl openQA openQA-worker os-autoinst-s390-deps os-autoinst-ipmi-deps && \
    zypper in -yl qemu-arm qemu-ppc qemu-x86 qemu-tools && \
    zypper in -yl qemu-hw-display-virtio-gpu qemu-hw-display-virtio-gpu-pci qemu-hw-display-virtio-vga && \
    zypper in -yl kmod && \
    zypper in -yl qemu-ovmf-x86_64 ovmf ovmf-tools && \
    zypper in -yl qemu-uefi-aarch64  && \
    zypper in -yl vde2 vde2-slirp && \
    zypper in -yl vim iputils iproute patch && \
    zypper in -yl python3 python3-jsonschema gcc make curl perl-App-cpanminus e2fsprogs \
        perl-SemVer perl-DateTime perl-NetAddr-IP perl-Test-Assert perl-JSON && \
    zypper clean && \
    mkdir -p /root/qemu

RUN cpanm REST::Client

 # fix all ownership/permissions
 RUN chown -R _openqa-worker /usr/share/openqa /var/lib/openqa && \
        find /usr/share/openqa /var/lib/openqa -type d -exec chmod ug+x {} \;

 # create a directory to hold the configurations bound in from host
RUN mkdir /conf
