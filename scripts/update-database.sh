#!/bin/bash

source /usr/local/bin/database-utils.sh

echo ">> wait for mysqldb"
wait_db

echo ">> init db (if necessary)"
init_db

if [ "$ACONF_CLEAR_DB" = 'true' ]; then
  echo ">> clearing old database"
  clear_db
fi

env | grep '^ACONF_USER_ACCOUNT_NAME_' | while read I_CONF
do
  NAME=$(echo "$I_CONF" | cut -d'=' -f1 | sed 's/ACONF_USER_ACCOUNT_NAME_//g')
  VALUE=$(echo "$I_CONF" | sed 's/^[^=]*=//g')

  EMAIL="$VALUE"

  PASSWORD_HASH=$(env | grep '^ACONF_USER_PASSWORD_HASH_'"$NAME" | sed 's/^[^=]*=//g')

  ALIASES=$(env | grep '^ACONF_USER_ALIASES_'"$NAME" | sed 's/^[^=]*=//g')

  echo ">> add user $NAME / $EMAIL"
  add_user "$EMAIL" "$PASSWORD_HASH"

  echo ">> adding aliases for user $NAME / $EMAIL:"
  for ALIAS in $ALIASES;
  do
    echo "  >> adding alias $ALIAS"
    add_virtual_alias "$ALIAS" "$EMAIL"
  done
done
