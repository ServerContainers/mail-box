#!/bin/bash

cat <<EOF
################################################################################

Welcome to the ghcr.io/servercontainers/mail-box

################################################################################

You'll find this container sourcecode here:

    https://github.com/ServerContainers/mail-box

The container repository will be updated regularly.

################################################################################


EOF

#
# can be done on every start...
#
chown -R vmail:vmail /var/vmail

AVAILABLE_NETWORKS="127.0.0.0/8"
if [ ! -z ${AUTO_TRUST_NETWORKS+x} ]; then
  AVAILABLE_NETWORKS=$(list-available-networks.sh | tr '\n' ',' | sed 's/,$//g')
  echo ">> trust all available networks: $AVAILABLE_NETWORKS"
fi

postconf -e "mynetworks=$AVAILABLE_NETWORKS"

if [ ! -z ${ADDITIONAL_MYNETWORKS+x} ]; then
  echo ">> update mynetworks to: $AVAILABLE_NETWORKS,$ADDITIONAL_MYNETWORKS"
  postconf -e "mynetworks=$AVAILABLE_NETWORKS,$ADDITIONAL_MYNETWORKS"
fi

if [ ! -z ${MYNETWORKS+x} ]; then
  if [ ! -z ${ADDITIONAL_MYNETWORKS+x} ]; then
    echo ">> Warning ADDITIONAL_MYNETWORKS will be ignored! only $MYNETWORKS will be set!"
  fi
  echo ">> update mynetworks to: $MYNETWORKS"
  postconf -e "mynetworks=$MYNETWORKS"
fi


# only on container creation
INITIALIZED="/.initialized"
if [ ! -f "$INITIALIZED" ]; then
	touch "$INITIALIZED"

  ###
  # Database Settings
  ###

  # Variables

  if [ -z ${MYSQL_PORT+x} ]
  then
    export MYSQL_PORT=3306
  fi
  echo ">> using '$MYSQL_PORT' as Database Server Port"

  if [ -z ${MYSQL_DBNAME+x} ]
  then
    export MYSQL_DBNAME="mailserver"
  fi
  echo ">> using '$MYSQL_DBNAME' as Database Name"

  if [ -z ${MYSQL_HOST+x} ]
  then
    echo ">> using local mysql server"
    export MYSQL_HOST=localhost
    export MYSQL_USER=dbuser
    export MYSQL_PASSWORD=dbpassword

    /usr/bin/mysqld_safe &
    echo ">> waiting for mysql socket."
    while [ ! -e "/var/run/mysqld/mysqld.sock" ]; do sleep 1; echo -n "."; done
    echo ""; echo ">> mysql socket found :)"

    echo "CREATE DATABASE $MYSQL_DBNAME;" > /tmp/autocreatedb.mysql
    echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" >> /tmp/autocreatedb.mysql
    echo "GRANT USAGE ON *.* TO '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;" >> /tmp/autocreatedb.mysql
    echo "GRANT ALL PRIVILEGES ON $MYSQL_DBNAME.* TO '$MYSQL_USER'@'%';" >> /tmp/autocreatedb.mysql
    echo "FLUSH PRIVILEGES;" >> /tmp/autocreatedb.mysql

    sh -c "mysql < /tmp/autocreatedb.mysql && echo '>> db '$MYSQL_DBNAME' successfully installed'; rm /tmp/autocreatedb.mysql; update-database.sh"
    
    killall mysqld
  else
    echo ">> using '$MYSQL_HOST' as Database Host"
    
    if [ -z ${MYSQL_USER+x} ]
    then
      >&2 echo ">> you need to specify a Database User!"
      exit 2;
    fi

    if [ -z ${MYSQL_PASSWORD+x} ]
    then
      >&2 echo ">> you need to specify a Password for the Database User!"
      exit 2;
    fi
  fi

  if [ -z ${DEFAULT_PASS_SCHEME+x} ]
  then
    DEFAULT_PASS_SCHEME="SHA512-CRYPT"
  fi
  echo ">> using '$DEFAULT_PASS_SCHEME' as Dovecots default_pass_scheme"

  # Settings

  sed -i "s/\[MYSQL_HOST\]/$MYSQL_HOST/g" /etc/postfix/mysql-virtual-mailbox-domains.cf
  sed -i "s/\[MYSQL_PORT\]/$MYSQL_PORT/g" /etc/postfix/mysql-virtual-mailbox-domains.cf
  sed -i "s/\[DB_NAME\]/$MYSQL_DBNAME/g" /etc/postfix/mysql-virtual-mailbox-domains.cf
  sed -i "s/\[DB_USER\]/$MYSQL_USER/g" /etc/postfix/mysql-virtual-mailbox-domains.cf
  sed -i "s/\[DB_PASSWORD\]/$MYSQL_PASSWORD/g" /etc/postfix/mysql-virtual-mailbox-domains.cf

  sed -i "s/\[MYSQL_HOST\]/$MYSQL_HOST/g" /etc/postfix/mysql-virtual-mailbox-maps.cf
  sed -i "s/\[MYSQL_PORT\]/$MYSQL_PORT/g" /etc/postfix/mysql-virtual-mailbox-maps.cf
  sed -i "s/\[DB_NAME\]/$MYSQL_DBNAME/g" /etc/postfix/mysql-virtual-mailbox-maps.cf
  sed -i "s/\[DB_USER\]/$MYSQL_USER/g" /etc/postfix/mysql-virtual-mailbox-maps.cf
  sed -i "s/\[DB_PASSWORD\]/$MYSQL_PASSWORD/g" /etc/postfix/mysql-virtual-mailbox-maps.cf

  sed -i "s/\[MYSQL_HOST\]/$MYSQL_HOST/g" /etc/postfix/mysql-virtual-alias-maps.cf
  sed -i "s/\[MYSQL_PORT\]/$MYSQL_PORT/g" /etc/postfix/mysql-virtual-alias-maps.cf
  sed -i "s/\[DB_NAME\]/$MYSQL_DBNAME/g" /etc/postfix/mysql-virtual-alias-maps.cf
  sed -i "s/\[DB_USER\]/$MYSQL_USER/g" /etc/postfix/mysql-virtual-alias-maps.cf
  sed -i "s/\[DB_PASSWORD\]/$MYSQL_PASSWORD/g" /etc/postfix/mysql-virtual-alias-maps.cf

  sed -i "s/\[MYSQL_HOST\]/$MYSQL_HOST/g" /etc/postfix/mysql-email2email.cf
  sed -i "s/\[MYSQL_PORT\]/$MYSQL_PORT/g" /etc/postfix/mysql-email2email.cf
  sed -i "s/\[DB_NAME\]/$MYSQL_DBNAME/g" /etc/postfix/mysql-email2email.cf
  sed -i "s/\[DB_USER\]/$MYSQL_USER/g" /etc/postfix/mysql-email2email.cf
  sed -i "s/\[DB_PASSWORD\]/$MYSQL_PASSWORD/g" /etc/postfix/mysql-email2email.cf

  sed -i "s/\[MYSQL_HOST\]/$MYSQL_HOST/g" /etc/dovecot/dovecot-sql.conf.ext
  sed -i "s/\[MYSQL_PORT\]/$MYSQL_PORT/g" /etc/dovecot/dovecot-sql.conf.ext
  sed -i "s/\[DB_NAME\]/$MYSQL_DBNAME/g" /etc/dovecot/dovecot-sql.conf.ext
  sed -i "s/\[DB_USER\]/$MYSQL_USER/g" /etc/dovecot/dovecot-sql.conf.ext
  sed -i "s/\[DB_PASSWORD\]/$MYSQL_PASSWORD/g" /etc/dovecot/dovecot-sql.conf.ext
  sed -i "s/\[DEFAULT_PASS_SCHEME\]/$DEFAULT_PASS_SCHEME/g" /etc/dovecot/dovecot-sql.conf.ext

  # update database if necessary
  if [ "$MYSQL_HOST" != "localhost" ]; then
    update-database.sh
  fi

  #
  # General
  #

  if [ -z ${RELAYHOST+x} ]; then
    echo ">> it is advised to use this container with a relayhost (maybe use servercontainers/mail-gateway)..."
  else
    echo ">> setting relayhost to: $RELAYHOST"
    postconf -e "relayhost=$RELAYHOST"
  fi

  if [ -z ${MAIL_FQDN+x} ]; then
    MAIL_FQDN="mailbox.local"
  fi

  if echo "$MAIL_FQDN" | grep -v '\.'; then
    MAIL_FQDN="$MAIL_FQDN.local"
  fi
  MAIL_FQDN=$(echo "$MAIL_FQDN" | sed 's/[^.0-9a-z\-]//g')

  MAIL_NAME=$(echo "$MAIL_FQDN" | cut -d'.' -f1)
  MAILDOMAIN=$(echo "$MAIL_FQDN" | cut -d'.' -f2-)

  echo ">> set mail host to: $MAIL_FQDN"
  echo "$MAIL_FQDN" > /etc/mailname
  echo "$MAIL_NAME" > /etc/hostname
  postconf -e "myhostname=$MAIL_FQDN"

  if [ -z ${POSTFIX_SMTPD_BANNER+x} ]; then
    POSTFIX_SMTPD_BANNER="$MAIL_FQDN ESMTP"
  fi
  echo ">> POSTFIX set smtpd_banner = $POSTFIX_SMTPD_BANNER"
  postconf -e "smtpd_banner=$POSTFIX_SMTPD_BANNER"

  if [ -z ${MAIL_POSTMASTER_ADDRESS+x} ]
  then
    MAIL_POSTMASTER_ADDRESS="postmaster@$MAIL_FQDN"
  fi
  echo "postmaster_address = $MAIL_POSTMASTER_ADDRESS" >> /etc/dovecot/conf.d/15-lda.conf


  #
  # SSL
  #

  if [ -z ${POSTFIX_SSL_OUT_CERT+x} ]; then
    POSTFIX_SSL_OUT_CERT="/etc/postfix/tls/client.crt"
  fi

  if [ -z ${POSTFIX_SSL_OUT_KEY+x} ]; then
    POSTFIX_SSL_OUT_KEY="/etc/postfix/tls/client.key"
  fi

  if [ -z ${POSTFIX_SSL_OUT_SECURITY_LEVEL+x} ]; then
    POSTFIX_SSL_OUT_SECURITY_LEVEL="may"
  fi

  if [[ -f "$POSTFIX_SSL_OUT_CERT" && -f "$POSTFIX_SSL_OUT_KEY" ]]; then
    echo ">> POSTFIX SSL - enabling outgoing SSL"
cat <<EOF >> /etc/postfix/main.cf
##### TLS settings ######

### outgoing connections ###
# smtp_tls_security_level=encrypt # for secure connections only
smtp_tls_security_level=$POSTFIX_SSL_OUT_SECURITY_LEVEL
smtp_tls_cert_file=$POSTFIX_SSL_OUT_CERT
smtp_tls_key_file=$POSTFIX_SSL_OUT_KEY

smtp_tls_exclude_ciphers = aNULL, DES, RC4, MD5, 3DES
smtp_tls_mandatory_exclude_ciphers = aNULL, DES, RC4, MD5, 3DES
smtp_tls_protocols = !SSLv3
smtp_tls_mandatory_protocols = !SSLv3
smtp_tls_mandatory_ciphers=high

smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache
smtp_tls_loglevel = 1
EOF
  fi

  if [ -z ${POSTFIX_SSL_IN_CERT+x} ]; then
    POSTFIX_SSL_IN_CERT="/etc/postfix/tls/bundle.crt"
  fi

  if [ -z ${POSTFIX_SSL_IN_KEY+x} ]; then
    POSTFIX_SSL_IN_KEY="/etc/postfix/tls/cert.key"
  fi

  if [ -z ${POSTFIX_SSL_IN_SECURITY_LEVEL+x} ]; then
    POSTFIX_SSL_IN_SECURITY_LEVEL="may"
  fi

  if [[ ! -f "$POSTFIX_SSL_IN_CERT" || ! -f "$POSTFIX_SSL_IN_KEY" ]]; then
    echo ">> POSTFIX SSL - generating incoming self signed ssl cert"
    openssl req -new -x509 -days 3650 -nodes \
      -newkey rsa:4096 \
      -subj "/C=XX/ST=XXXX/L=XXXX/O=XXXX/CN=$MAIL_FQDN" \
      -out "$POSTFIX_SSL_IN_CERT" \
      -keyout "$POSTFIX_SSL_IN_KEY" \
      -sha256
  fi

  if [[ -f "$POSTFIX_SSL_IN_CERT" && -f "$POSTFIX_SSL_IN_KEY" ]]; then
    echo ">> POSTFIX SSL - enabling incoming SSL"
cat <<EOF >> /etc/postfix/main.cf
### incoming connections ###
# smtpd_tls_security_level=encrypt # for secure connections only
smtpd_tls_security_level=$POSTFIX_SSL_IN_SECURITY_LEVEL
smtpd_tls_cert_file=$POSTFIX_SSL_IN_CERT
smtpd_tls_key_file=$POSTFIX_SSL_IN_KEY

smtpd_tls_exclude_ciphers = aNULL, DES, RC4, MD5, 3DES
smtpd_tls_mandatory_exclude_ciphers = aNULL, DES, RC4, MD5, 3DES
smtpd_tls_protocols = !SSLv3
smtpd_tls_mandatory_protocols = !SSLv3
smtpd_tls_mandatory_ciphers=high

smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtpd_tls_loglevel = 1
EOF
  fi

  if [ -f /etc/postfix/tls/rootCA.crt ]; then
    echo ">> POSTFIX SSL - enabling CA based Client Authentication"
    postconf -e smtpd_tls_ask_ccert=yes
    postconf -e smtpd_tls_CAfile=/etc/postfix/tls/rootCA.crt
    postconf -e smtpd_recipient_restrictions=permit_mynetworks,permit_sasl_authenticated,permit_tls_all_clientcerts,reject_unauth_destination
  fi

  if [ -f /etc/postfix/tls/dh1024.pem ]; then
    echo ">> using dh1024.pem provided in volume"
  else
    cp /etc/postfix/dh1024.pem /etc/postfix/tls/dh1024.pem
  fi

  if [ -f /etc/postfix/tls/dh512.pem ]; then
    echo ">> using dh512.pem provided in volume"
  else
    cp /etc/postfix/dh512.pem /etc/postfix/tls/dh512.pem
  fi

  #
  # Settings
  #

  if [ ! -z ${POSTFIX_QUEUE_LIFETIME_BOUNCE+x} ]; then
    echo ">> POSTFIX set bounce_queue_lifetime = $POSTFIX_QUEUE_LIFETIME_BOUNCE"
    postconf -e "bounce_queue_lifetime=$POSTFIX_QUEUE_LIFETIME_BOUNCE"
  fi

  if [ ! -z ${POSTFIX_QUEUE_LIFETIME_MAX+x} ]; then
    echo ">> POSTFIX set maximal_queue_lifetime = $POSTFIX_QUEUE_LIFETIME_MAX"
    postconf -e "maximal_queue_lifetime=$POSTFIX_QUEUE_LIFETIME_MAX"
  fi

  if [ ! -z ${POSTFIX_MYDESTINATION+x} ]; then
    echo ">> POSTFIX set mydestination = $POSTFIX_MYDESTINATION"
    postconf -e "mydestination=$POSTFIX_MYDESTINATION"
  fi

  if [ -f /etc/postfix/additional/transport ]; then
    echo ">> POSTFIX found 'additional/transport' activating it as transport_maps"
    postmap /etc/postfix/additional/transport
    postconf -e "transport_maps = hash:/etc/postfix/additional/transport"
  fi

  if [ -f /etc/postfix/additional/header_checks ]; then
    echo ">> POSTFIX found 'additional/header_checks' activating it as header_checks"
    postconf -e "header_checks = regexp:/etc/postfix/additional/header_checks"
  fi

  ##
  # SQL Statements
  ##

  if [ -z ${SQL_VIRTUAL_MAILBOX_DOMAIN+x} ]; then
    SQL_VIRTUAL_MAILBOX_DOMAIN="SELECT 1 FROM virtual_domains WHERE name='%s'"
  fi
  echo ">> SQL_VIRTUAL_MAILBOX_DOMAIN: $SQL_VIRTUAL_MAILBOX_DOMAIN"
  echo "query = $SQL_VIRTUAL_MAILBOX_DOMAIN" >> /etc/postfix/mysql-virtual-mailbox-domains.cf

  if [ -z ${SQL_VIRTUAL_MAILBOX_MAPS+x} ]; then
    SQL_VIRTUAL_MAILBOX_MAPS="SELECT 1 FROM virtual_users WHERE email='%s'"
  fi
  echo ">> SQL_VIRTUAL_MAILBOX_MAPS: $SQL_VIRTUAL_MAILBOX_MAPS"
  echo "query = $SQL_VIRTUAL_MAILBOX_MAPS" >> /etc/postfix/mysql-virtual-mailbox-maps.cf

  if [ -z ${SQL_VIRTUAL_ALIAS_MAPS+x} ]; then
    SQL_VIRTUAL_ALIAS_MAPS="SELECT destination FROM virtual_aliases WHERE source='%s'"
  fi
  echo ">> SQL_VIRTUAL_ALIAS_MAPS: $SQL_VIRTUAL_ALIAS_MAPS"
  echo "query = $SQL_VIRTUAL_ALIAS_MAPS" >> /etc/postfix/mysql-virtual-alias-maps.cf

  if [ -z ${SQL_EMAIL_TO_EMAIL+x} ]; then
    SQL_EMAIL_TO_EMAIL="SELECT email FROM virtual_users WHERE email='%s'"
  fi
  echo ">> SQL_EMAIL_TO_EMAIL: $SQL_EMAIL_TO_EMAIL"
  echo "query = $SQL_EMAIL_TO_EMAIL" >> /etc/postfix/mysql-email2email.cf

  if [ -z ${SQL_DOVECOT_PASSWORD_QUERY+x} ]; then
    SQL_DOVECOT_PASSWORD_QUERY="SELECT email as user, password FROM virtual_users WHERE email='%u';"
  fi
  echo ">> SQL_DOVECOT_PASSWORD_QUERY: $SQL_DOVECOT_PASSWORD_QUERY"
  echo "password_query = $SQL_DOVECOT_PASSWORD_QUERY" >> /etc/dovecot/dovecot-sql.conf.ext

  ##
  # POSTFIX RAW Config ENVs
  ##
  if env | grep '^POSTFIX_RAW_CONFIG_'
  then
    echo -e "\n## POSTFIX_RAW_CONFIG ##\n" >> /etc/postfix/main.cf
    env | grep '^POSTFIX_RAW_CONFIG_' | while read I_CONF
    do
      CONFD_CONF_NAME=$(echo "$I_CONF" | cut -d'=' -f1 | sed 's/POSTFIX_RAW_CONFIG_//g' | tr '[:upper:]' '[:lower:]')
      CONFD_CONF_VALUE=$(echo "$I_CONF" | sed 's/^[^=]*=//g')

      echo "$CONFD_CONF_NAME""=""$CONFD_CONF_VALUE" >> /etc/postfix/main.cf
    done
  fi

  ###
  # RUNIT
  ###

  echo ">> RUNIT - create services"
  mkdir -p /etc/sv/rsyslog /etc/sv/postfix /etc/sv/dovecot /etc/sv/mysqld
  
  echo -e '#!/bin/sh\nexec /usr/bin/mysqld_safe' > /etc/sv/mysqld/run
    echo -e '#!/bin/sh\nkillall mysqld' > /etc/sv/mysqld/finish

  
  echo -e '#!/bin/sh\nexec /usr/sbin/rsyslogd -n' > /etc/sv/rsyslog/run
    echo -e '#!/bin/sh\nrm /var/run/rsyslogd.pid' > /etc/sv/rsyslog/finish
    
  echo -e '#!/bin/sh\nservice postfix start; sleep 5; while ps aux | grep [p]ostfix | grep [m]aster > /dev/null 2> /dev/null; do sleep 5; done' > /etc/sv/postfix/run
    echo -e '#!/bin/sh\nservice postfix stop' > /etc/sv/postfix/finish

  echo -e '#!/bin/sh\nexec /usr/sbin/dovecot -F | logger -t dovecot' > /etc/sv/dovecot/run
  
  chmod a+x /etc/sv/*/run /etc/sv/*/finish

  echo ">> RUNIT - enable services"
  ln -s /etc/sv/dovecot /etc/service/dovecot
  ln -s /etc/sv/postfix /etc/service/postfix
  ln -s /etc/sv/rsyslog /etc/service/rsyslog
  [ "$MYSQL_HOST" = "localhost" ] && ln -s /etc/sv/mysqld /etc/service/mysqld

fi

##
# TLS Cert Renew Stuff
##

rm -rf /tmp/tls 2> /dev/null
cp -a /etc/postfix/tls /tmp/tls

echo ">> fix file permissions"
chgrp postfix /etc/postfix/m*.cf
chmod u=rw,g=r,o= /etc/postfix/m*.cf
chgrp vmail /etc/dovecot/dovecot.conf
chmod g+r /etc/dovecot/dovecot.conf
chown root:root /etc/dovecot/dovecot-sql.conf.ext
chmod go= /etc/dovecot/dovecot-sql.conf.ext

##
# CMD
##
echo ">> CMD: exec docker CMD"
echo "$@"
exec "$@"
