#!/bin/sh

init_db() {
  mysql -h $MYSQL_HOST:$MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DBNAME < /mysql-data-scheme.sql
}

run_mysql() {
  echo "$1" | mysql -h $MYSQL_HOST:$MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DBNAME | sed '1d'
}

get_domain_from_email() {
  EMAIL=$1

  # if it's an email address extract domain
  echo $EMAIL | grep '@' 2>/dev/null >/dev/null && EMAIL=$(echo $EMAIL | sed 's/.@//g')

  echo $EMAIL
}

get_domain_id() {
  DOMAIN=$(get_domain_from_email $1)

  ID=$(run_mysql "SELECT * FROM virtual_domains WHERE name = '$DOMAIN' LIMIT 1;" | awk '{print $1}')

  [ -z "$ID" ] && ID=-1

  echo $ID
}

add_domain_id() {
  DOMAIN=$(get_domain_from_email $1)

  ID=$(get_domain_id "$DOMAIN")

  [ $ID -le 0 ] && run_mysql "INSERT into virtual_domains (name) VALUES ('$DOMAIN');" >/dev/null

  get_domain_id "$DOMAIN"
}

add_virtual_alias() {
  SOURCE_MAIL=$1
  DEST_MAIL=$2

  CHECK=$(run_mysql "SELECT * FROM virtual_aliases WHERE source = '$SOURCE_MAIL' AND destination = '$DEST_MAIL';")

  # check if alias already exists
  if ! echo "$CHECK" | grep "$SOURCE_MAIL" | grep "$DEST_MAIL"
  then
    run_mysql "DELETE FROM virtual_aliases WHERE source = '$SOURCE_MAIL';"

    ID=$(add_domain_id "$SOURCE_MAIL")
  
    [ $ID -gt 0 ] && run_mysql "INSERT into virtual_aliases (domain_id, source, destination) VALUES ('$ID', '$SOURCE_MAIL', '$DEST_MAIL');" >/dev/null

  fi
}

add_user() {
  LOGIN_EMAIL=$1
  PASSWORD_HASH=$2

  run_mysql "DELETE FROM virtual_users WHERE email = '$LOGIN_EMAIL';"

  ID=$(add_domain_id "$LOGIN_EMAIL")
  
  [ $ID -gt 0 ] && run_mysql "INSERT into virtual_users (domain_id, password, email) VALUES ('$ID', '$PASSWORD_HASH', '$LOGIN_EMAIL');" >/dev/null
}

clear_db() {
  run_mysql "DELETE FROM virtual_aliases;
  run_mysql "DELETE FROM virtual_users;
  run_mysql "DELETE FROM virtual_domains;
}
