FROM quay.io/fedora/fedora
LABEL title="openqa_worker-fedora"

RUN dnf install -y openqa openqa-worker python3-jsonschema \
    perl-REST-Client procps-ng os-autoinst tunctl iproute

# fix all ownership/permissions
RUN chown -R _openqa-worker /usr/share/openqa /var/lib/openqa && \
	chmod ug+rw /usr/share/openqa /var/lib/openqa && \
	find /usr/share/openqa /var/lib/openqa -type d -exec chmod ug+x {} \;

# create a directory to hold the configurations bound in from host
RUN mkdir /conf
