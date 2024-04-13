#!/bin/bash
# If running locally, define values e.g.
# SERVER_NAME='' DETACHED=yes ./start-openqa-reverse-proxy.sh

set -ex
IMAGE=quay.io/fedora/httpd-24:latest
SSL_CONF="${SRV}/conf/openqa-proxy-ssl.conf"
HTTP_CONF="${SRV}/conf/openqa-proxy.conf"

if [ ! -f "$SSL_CONF" ]; then
  echo "Missing $SSL_CONF"
  exit
fi

if [ ! -f "$HTTP_CONF" ]; then
  echo "Missing $HTTP_CONF"
  exit
fi

if [[ -z $(podman images --format "{{.Tag}}" $IMAGE) ]]; then
    echo "$IMAGE is missing"
	exit
fi

# Remove any old containers that may have exited without cleanup
podman rm -a

# The public name or ip of the server
SERVER_NAME="openqa.fedorainfracloud.org"
if [ ! -f "${SRV}/conf/privkey.pem" ]; then
    SERVER_NAME="$(curl ipinfo.io/ip)"
fi

# The private ip of the container host, be careful to get just one value
# also don't make this localhost since it will be interpreted incorrectly as the container's localhost
if [ -z "${PROXY_DST}" ]; then
    PROXY_DST=$(hostname -I | awk '{print $1}')
fi

# The directory for openqa-reverse-proxy scripts and logs
if [ -z "${SRV}" ]; then
    SRV='/home/fedora/openqa-containers/openqa-reverse-proxy'
fi

if [ ! -d "${SRV}/logs" ] && [ ! -L "${SRV}}/logs" ]; then
	mkdir -p "${SRV}/logs"
fi

# If running locally without systemd, run the container detached so it
# won't be dependent on the terminal that it started in
if [[ "$DETACHED" == "true" ]] || [[ "$DETACHED" == "yes" ]]; then
    detached_arg="-d"
fi

/usr/bin/podman run --rm -i --name openqa-reverse-proxy \
	-p 80:80 -p 443:443 \
	${detached_arg} \
	--user=root \
	-e PROXY_DST=$PROXY_DST \
	-e SERVER_NAME=$SERVER_NAME \
	-v ${SRV}/conf:/conf/:z \
	-v ${SRV}/logs:/etc/httpd/logs/:z \
	-v ${SRV}/generate-certificate.sh:/generate-certificate.sh:z \
	-v ${SRV}/init-openqa-reverse-proxy.sh:/init-openqa-reverse-proxy.sh:z \
	$IMAGE /init-openqa-reverse-proxy.sh
