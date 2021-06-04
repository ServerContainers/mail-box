# Docker Mail Box Postfix/Dovecot/Sieve (servercontainers/mail-box)
_maintained by ServerContainers_

## Changelogs

* 2021-06-04
    * added healthcheck (will fail when certs are updated without container restart)
* 2020-11-05
    * multiarch build
    
## What is it

This Dockerfile (available as ___servercontainers/mail-box___) gives you a dovecot and postfix installation is meant to store mails, handle authentication and users and is based on the famous [Wordaround.org - ISP Mail Tutorials](https://workaround.org/ispmail)

It's based on the [_/debian:buster](https://registry.hub.docker.com/_/debian/) Image

View in Docker Registry [servercontainers/mail-box](https://registry.hub.docker.com/u/servercontainers/mail-box/)

View in GitHub [ServerContainers/mail-box](https://github.com/ServerContainers/mail-box)

All the user backend SQL Statements can be modified. By default they use the default isp mail statements and database scheme.

## Environment variables

__OFFICIAL USER DATABASE CONFIGURATION ENVIRONMENT VARIABLES__

- DEFAULT_PASS_SCHEME
    - dovecot default_pass_scheme for the password hashes (see dovecot manual)
    - default: _SHA512-CRYPT_
    - generate using: `doveadm pw -s SHA512-CRYPT`

- SQL_VIRTUAL_MAILBOX_DOMAIN
    - default: _SELECT 1 FROM virtual_domains WHERE name='%s'_
- SQL_VIRTUAL_MAILBOX_MAPS
    - default: _SELECT 1 FROM virtual_users WHERE email='%s'"_
- SQL_VIRTUAL_ALIAS_MAPS
    - default: _SELECT destination FROM virtual_aliases WHERE source='%s'"_
- SQL_EMAIL_TO_EMAIL
    - default: _SELECT email FROM virtual_users WHERE email='%s'"_

- SQL_DOVECOT_PASSWORD_QUERY
    - default: _SELECT email as user, password FROM virtual_users WHERE email='%u';"_

__OFFICIAL DATABASE ENVIRONMENT VARIABLES__
- MYSQL_HOST
    - default: will start internal mysql daemon
- MYSQL_USER
    - no default - if null it won't start
    - optional if internal mysql is used
- MYSQL_PASSWORD
    - no default - if null it won't start
    - optional if internal mysql is used
- MYSQL_PORT
    - default: _3306_ - if you use a different mysql port change it
    - optional if internal mysql is used
- MYSQL\_DBNAME
    - default: _mailserver_
    - optional if internal mysql is used

__OFFICIAL DATABASE MANAGMENT ENVIRONMENT VARIABLES__

_the following variables can be used for initializing/managing the database_

- ACONF_CLEAR_DB
    - set this to `true` and the database gets cleared
    - _might be used if you configure everything using envs and don't won't to keep outdated configuration_
    - might bringt a few seconds more downtime to the mail service

_the next one's need to be used to create a user/email, add a password hash to it and configure it's aliases_

- ACONF_USER_ACCOUNT_NAME_[...]
    - `[...]` must be replaced with an id to connect all the envs for one account together
    - the email address is specified in the value. e.g.: `test@mail.tld`

- ACONF_USER_PASSWORD_HASH_[...]
    - `[...]` must be replaced with an id to connect all the envs for one account together
    - the password hash is specified in the value. e.g.: `{SHA512-CRYPT}$6$asdfasdfsadfasf...`
    - Note: for a docker compose file you need to replace each `$` with a `$$` (then it's escaped and works)

- ACONF_USER_ALIASES_[...]
    - `[...]` must be replaced with an id to connect all the envs for one account together
    - the aliases for this users email are specified (use a blank to seperate multiplte) in the value. e.g.: `postmaster@mail.tld admin@mail.tld info@mail.tld`

__OFFICIAL MAIL ENVIRONMENT VARIABLES__

- MAIL_POSTMASTER_ADDRESS
    - the address to reach the postmaster (maybe you)

- MAIL_FQDN
    - specify the mailserver name - only add FQDN not a hostname!
    - e.g. _my.mailserver.example.com_
- POSTFIX_SMTPD_BANNER
    - alter the SMTPD Banner of postfix e.g. _mailserver.example.local ESMTP_

- POSTFIX_MYDESTINATION
    - specify the domains which this mail-box handles

- AUTO_TRUST_NETWORKS
    - add all networks this container is connected to and trust them to send mails
    - _set to any value to enable_
- ADDITIONAL_MYNETWORKS
    - add this specific network to the automatically trusted onces
- MYNETWORKS
    - ignore all auto configured _mynetworks_ and replace them with this value
    - _overwrites networks specified in ADDITIONAL_MYNETWORKS_

- RELAYHOST
    - sets postfix relayhost - please take a look at the official documentation
    - _The form enclosed with [] eliminates DNS MX lookups. Don't worry if you don't know what that means. Just be sure to specify the [] around the mailhub hostname that your ISP gave to you, otherwise mail may be mis-delivered._

- POSTFIX_SSL_OUT_CERT
    - path to SSL Client certificate (outgoing connections)
    - default: _/etc/postfix/tls/client.crt_
- POSTFIX_SSL_OUT_KEY
    - path to SSL Client key (outgoing connections)
    - default: _/etc/postfix/tls/client.key_
- POSTFIX_SSL_OUT_SECURITY_LEVEL
    - SSL security level for outgoing connections
    - default: _may_

- POSTFIX_SSL_IN_CERT
    - path to SSL Cert/Bundle (incoming connections)
    - default: _/etc/postfix/tls/bundle.crt_
- POSTFIX_SSL_IN_KEY
    - path to SSL Cert key (incoming connections)
    - default: _/etc/postfix/tls/cert.key_
- POSTFIX_SSL_IN_SECURITY_LEVEL
    - SSL security level for incoming connections
    - default: _may_

- POSTFIX_QUEUE_LIFETIME_BOUNCE
    - The  maximal  time  a  BOUNCE MESSAGE is queued before it is considered undeliverable
    - By default, this is the same as the queue life time for regular mail
- POSTFIX_QUEUE_LIFETIME_MAX
    - maximum lifetime of regular (non bounce) messages

__HIGH PRIORITY ENVIRONMENT VARIABLE__

the following variable/s are only if you have some specific settings you need.
They help you overwrite everything after the config was generated.
If you can update your setting with the variables from above, it is strongly recommended to use them!

_some characters might brake your configuration!_

- POSTFIX_RAW_CONFIG_<POSTFIX_SETTING_NAME>
    - set/edit all configurations in /etc/postfix/main.cf using the POSTFIX_RAW_CONFIG_ followed by the setting name

_for example: to set_ ___mynetworks_style = subnet___ _just add a environment variable_ ___POSTFIX_RAW_CONFIG_MYNETWORKS_STYLE=subnet___

## Volumes

- /etc/postfix/tls
    - this is where the container looks for:
        - dh1024.pem (to overwrite the one generated at container build)
        - dh512.pem (to overwrite the one generated at container build)
        - rootCA.crt (to check valid client certificates against)
        - client.crt (outgoing SSL Client cert)
        - client.key (outgoing SSL Client key)
        - bundle.crt (incoming SSL Server cert/bundle)
        - cert.key (incoming SSL Server key)
- /etc/postfix/additional
    - this is where the container looks for:
        - transport (postfix transport text-file - without been postmaped)
        - header_checks (postfix header_checks regex file)
