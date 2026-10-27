#!/usr/bin/env bash
# Проверка конфигурации сервера (ПР5 + ПР6)
set -u
status=0
check(){ # описание, команда
  if bash -c "$2" >/dev/null 2>&1; then echo "OK    $1"; else echo "FAIL  $1"; status=1; fi
}
echo "[1] SSH"
check "порт SSH не 22" '[ "$(sudo sshd -T | awk "/^port /{print \$2}")" != "22" ]'
check "MaxAuthTries = 3" '[ "$(sudo sshd -T | awk "/^maxauthtries /{print \$2}")" = "3" ]'
echo "[2] UFW"
check "UFW default incoming: deny" 'sudo ufw status verbose | grep -q "deny (incoming)"'
echo "[4] Веб-сервер"
DAYS="${CERT_DAYS:-30}"
check "служба nginx активна" 'systemctl is-active --quiet nginx'
check "nginx -t без ошибок" 'sudo nginx -t'
check "сертификат действителен ещё $DAYS дн." "openssl x509 -in /etc/ssl/certs/devops.crt -noout -checkend $((DAYS*86400))"
check "нет файлов с записью для всех" '[ -z "$(find /var/www/devops-site -perm -o+w)" ]'
check "права ключа 600" '[ "$(sudo stat -c %a /etc/ssl/private/devops.key)" = "600" ]'
exit $status
