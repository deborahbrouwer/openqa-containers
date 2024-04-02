FROM quay.io/fedora/fedora
LABEL title="openqa-consumer"

# Using the fedora-messaging certificates from dnf fedora-messaging, but run the pip version
RUN dnf install -y fedora-messaging util-linux procps-ng git

RUN python3 -m venv venv
RUN source /venv/bin/activate && \
	mkdir -p /venv/etc/ && \
	pip install fedora-messaging requests
