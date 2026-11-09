#!/usr/bin/env bash
set -uo pipefail
through=${AUDIT_THROUGH:-8}
days=${CERT_DAYS:-30}
home=/home/devops
pass=0 fail=0
check() {
  if [[ "$2" == "$3" ]]; then printf '[OK] %s\n' "$1"; ((pass += 1))
  else printf '[FAIL] %s (expected %s, got %s)\n' "$1" "$2" "$3"; ((fail += 1)); fi
}
ok() { if "$@" >/dev/null 2>&1; then echo ok; else echo failed; fi; }
admin() { if (( EUID == 0 )); then "$@"; else sudo -n "$@"; fi; }
setting() { awk -v key="$1" '$1 == key {print $2; exit}' <<< "$ssh_config"; }
compose() { ( cd "$home/$1" && shift && admin docker compose "$@" ); }
printf 'Server audit | %s | %s\n' "$(hostname -f)" "$(date -Is)"
echo '[1] SSH'
ssh_config=$(admin /usr/sbin/sshd -T 2>/dev/null) || ssh_config=
check 'PermitRootLogin' no "$(setting permitrootlogin)"
check 'PasswordAuthentication' no "$(setting passwordauthentication)"
check 'MaxAuthTries' 3 "$(setting maxauthtries)"
check 'Nonstandard SSH port' yes "$(if [[ -n "$(setting port)" && "$(setting port)" != 22 ]]; then echo yes; fi)"
echo '[2] UFW'
ufw=$(LC_ALL=C admin ufw status verbose 2>/dev/null) || ufw=
check 'UFW active' active "$(awk '/^Status:/ { print $2 }' <<< "$ufw")"
check 'Incoming policy' deny "$(awk '/^Default:/ { print $2 }' <<< "$ufw")"
echo '[3] Accounts'
awk -F: '$3 >= 1000 && $3 < 65534 {printf "  %s (uid=%s)\n",$1,$3}' /etc/passwd
if (( through >= 6 )); then
  echo '[4] Web server'
  check 'Nginx active' active "$(systemctl is-active nginx)"
  check 'Nginx syntax' ok "$(ok admin nginx -t)"
  check "Certificate valid for $days days" ok "$(ok openssl x509 -in /etc/ssl/certs/devops.crt -noout -checkend "$((days * 86400))")"
  writable=$(find /var/www/devops-site -perm -o+w -print 2>/dev/null) || writable=ERROR
  check 'No world-writable site files' '' "$writable"
  check 'TLS key mode' 600 "$(admin stat -c '%a' /etc/ssl/private/devops.key)"
fi
if (( through >= 7 )); then
  echo '[5] Containers'
  check 'Docker active' active "$(systemctl is-active docker)"
  db=$(compose app ps -q db 2>/dev/null) || db=
  check 'PostgreSQL healthy' healthy "$(admin docker inspect -f '{{.State.Health.Status}}' "$db" 2>/dev/null)"
  check 'App bound to loopback' 127.0.0.1:5000 "$(compose app port app 5000 2>/dev/null)"
  check 'No externally listening PostgreSQL or app socket' '' "$(ss -H -ltn '( sport = :5000 or sport = :5432 )' | awk '$4 !~ /^127[.]0[.]0[.]1:/ { print $4 }')"
  check 'PostgreSQL environment file mode' 600 "$(stat -c '%a' "$home/app/.env")"
fi
if (( through >= 8 )); then
  echo '[6] Redis application'
  redis=$(compose kr2 ps -q redis 2>/dev/null) || redis=
  check 'Redis healthy' healthy "$(admin docker inspect -f '{{.State.Health.Status}}' "$redis" 2>/dev/null)"
  check 'KR2 bound to loopback' 127.0.0.1:8004 "$(compose kr2 port app 8004 2>/dev/null)"
  check 'No published Redis port' '' "$(compose kr2 port redis 6379 2>/dev/null)"
  check 'Redis environment file mode' 600 "$(stat -c '%a' "$home/kr2/.env")"
  check 'KR2 TLS key mode and owner' '600 root' "$(admin stat -c '%a %U' /etc/ssl/private/kr2.key)"
  check 'HTTPS health' ok "$(ok curl -fsS --cacert /etc/ssl/certs/kr2.crt --resolve kv.devops.local:443:127.0.0.1 https://kv.devops.local/health)"
fi
printf 'Passed: %s; failed: %s\n' "$pass" "$fail"
(( fail == 0 ))
