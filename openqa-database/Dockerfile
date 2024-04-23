FROM quay.io/fedora/postgresql-15:latest
LABEL title="openqa-database"

USER root

RUN dnf install -y openqa procps-ng iproute vim

RUN mkdir -p  /conf

# fix all ownership/permissions
RUN chown -R geekotest /usr/share/openqa /var/lib/openqa && \
	chmod ug+rw /usr/share/openqa /var/lib/openqa && \
	find /usr/share/openqa /var/lib/openqa -type d -exec chmod ug+x {} \;
