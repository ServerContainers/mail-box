#!/bin/sh
# Automated smoke test for the mail-box container.
# Builds the image, runs it (with the built-in local MySQL), waits for the
# services to come up and asserts that postfix, dovecot (2.4) and mariadb work.
set -e

IMG=mailbox-test
CN=mailbox-test-run

cleanup() { docker rm -f "$CN" >/dev/null 2>&1 || true; }
trap cleanup EXIT

fail() { echo "FAIL: $1"; exit 1; }

echo ">> building image"
docker build -t "$IMG" .

echo ">> starting container"
docker rm -f "$CN" >/dev/null 2>&1 || true
docker run -d --name "$CN" -e MAIL_FQDN=mail01.test.tld "$IMG" >/dev/null

echo ">> waiting for dovecot to listen on 143 (up to 120s)"
up=0
for _ in $(seq 1 60); do
  if docker exec "$CN" bash -c 'exec 3<>/dev/tcp/127.0.0.1/143' 2>/dev/null; then up=1; break; fi
  sleep 2
done
[ "$up" = 1 ] || fail "dovecot did not start listening on 143 in time"

echo ">> assert: container is running"
[ "$(docker inspect -f '{{.State.Running}}' "$CN")" = true ] || fail "container not running"
echo "ok - container running"

echo ">> assert: postfix master present"
docker exec "$CN" sh -c "ps aux | grep -q '[s]bin/master'" || fail "postfix master not running"
echo "ok - postfix master running"

echo ">> assert: dovecot present"
docker exec "$CN" sh -c "ps aux | grep -q '[d]ovecot'" || fail "dovecot not running"
echo "ok - dovecot running"

echo ">> assert: mariadb present"
docker exec "$CN" sh -c "ps aux | grep -q '[m]ariadbd'" || fail "mariadbd not running"
echo "ok - mariadbd running"

echo ">> assert: postfix check exits 0"
docker exec "$CN" postfix check || fail "postfix check reported problems"
echo "ok - postfix check passed"

echo ">> assert: doveconf -n has no config errors"
docker exec "$CN" doveconf -n >/dev/null 2>&1 || fail "doveconf -n reported a config error"
echo "ok - doveconf -n clean"

echo ">> assert: SMTP on port 25 returns a 220 banner"
banner=$(docker exec "$CN" bash -c 'exec 3<>/dev/tcp/127.0.0.1/25; head -1 <&3' | tr -d '\r')
echo "$banner" | grep -q '^220' || fail "no SMTP 220 banner (got: $banner)"
echo "ok - SMTP banner: $banner"

echo ">> assert: IMAP on port 143 returns a * OK greeting"
greet=$(docker exec "$CN" bash -c 'exec 3<>/dev/tcp/127.0.0.1/143; head -1 <&3' | tr -d '\r')
echo "$greet" | grep -q '^\* OK' || fail "no IMAP greeting (got: $greet)"
echo "ok - IMAP greeting: $greet"

echo ">> assert: dovecot SQL passdb answers (no SQL error for unknown user)"
docker exec "$CN" doveadm auth test nobody@test.tld wrongpass >/dev/null 2>&1 || true
docker exec "$CN" doveadm log errors 2>/dev/null | grep -qi 'sql.*syntax' && fail "dovecot SQL query has a syntax error" || true
echo "ok - SQL passdb reachable"

echo ""
echo "ALL TESTS PASSED"
