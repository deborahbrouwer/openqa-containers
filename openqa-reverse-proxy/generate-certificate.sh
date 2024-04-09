#!/bin/bash
set -e

    echo "Generating new certificates"
    sed -i '/#ServerName www.example.com:80/a\ServerName openqa.fedorainfracloud.org' /etc/httpd/conf/httpd.conf

    # Use the configs that include mod_md
    ln -s /conf/openqa-ssl.conf /etc/httpd/conf.d/openqa-ssl.conf
    ln -s /conf/openqa.conf /etc/httpd/conf.d/openqa.conf

    # Apache mod_md will request them the configs from the MDCertificateAuthority as
    # specified in openqa-ssl.conf but only if there are no other certificates available,

    # remove localhost cert
    rm -rf /etc/pki/tls/certs/localhost.crt
    rm -rf /etc/pki/tls/private/localhost.key
    sed -i '/SSLCertificateFile/s/^/#/' /etc/httpd/conf.d/ssl.conf
    sed -i '/SSLCertificateKeyFile/s/^/#/' /etc/httpd/conf.d/ssl.conf

    # don't look for pubcert
    sed -i '/SSLCertificateFile/s/^/#/' /conf/openqa-ssl.conf
    sed -i '/SSLCertificateKeyFile/s/^/#/' /conf/openqa-ssl.conf

    # New certs will be in /var/lib/httpd/md/domains/openqa.fedorainfracloud.org/
    # Copy them outside of the container to bind them in again later
    # see https://github.com/icing/mod_md
  fi

}