FROM quay.io/fedora/fedora
LABEL title="openqa-webserver"

RUN dnf install -y openqa

# openQA pull request #5463 "assets-via-npm" requires that we now get these packages locally
RUN dnf install -y nodejs && \
	npm install -g npm@10.5.0 && \
	cd /usr/share/openqa/ && \
	npm init -y && \
	npm install --save anser@^2.1.1 bootstrap@^4.6.1 chosen-js@^1.8.7 codemirror@^5.58.2 d3@^4.13.0 \
	dagre-d3@^0.6.4 datatables@^1.10.18 datatables.net-bs4@^1.13.8 fork-awesome@^1.2.0 jquery@^3.7.1 \
	jquery-ujs@^1.2.3 shepherd.js@^11.2.0 timeago@^1.6.7

# do not force fixes as the specific version are required and will break otherwise
RUN npm audit fix || true

RUN dnf install -y openqa-local-db \
	perl-Mojolicious perl-Mojolicious-Plugin-AssetPack \
	ruby-devel 'rubygem(sass)' python3-jsonschema wget procps-ng

RUN dnf install -y openqa-httpd mod_ssl mod_proxy_html mod_session mod_md

RUN ln -s /etc/httpd/conf.modules.d/00-base.conf /etc/httpd/conf.modules.d/00-base.load
RUN ln -s /etc/httpd/conf.modules.d/00-ssl.conf /etc/httpd/conf.modules.d/00-ssl.load
RUN /usr/libexec/httpd-ssl-gencerts

# fix all ownership/permissions
RUN chown -R geekotest /usr/share/openqa /var/lib/openqa && \
	chmod ug+rw /usr/share/openqa /var/lib/openqa && \
	find /usr/share/openqa /var/lib/openqa -type d -exec chmod ug+x {} \;
