#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail
REMOTE="${REMOTE-devops}"                 # пусто = локальная доставка (стенд внутри ВМ)
REMOTE_DIR="${REMOTE_DIR:-/var/www/devops-site}"
SITE_URL="${SITE_URL:-https://devops.local}"
CA_CERT="${CA_CERT:-${HOME}/devops.crt}"
RESOLVE="${RESOLVE:-}"
ROOT="$(git rev-parse --show-toplevel)"
LOCAL_DIR="${ROOT}/site/"
DRY=""
[ "${1:-}" = "--dry-run" ] && DRY="--dry-run"
[ -f "${LOCAL_DIR}index.html" ] || { echo "ОШИБКА: нет site/index.html" >&2; exit 1; }
if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then echo "ОШИБКА: есть незафиксированные изменения" >&2; exit 1; fi
DEST="${REMOTE_DIR}/"; [ -n "$REMOTE" ] && DEST="${REMOTE}:${REMOTE_DIR}/"
rsync -avz --delete --chmod=D755,F644 $DRY -e "ssh -o BatchMode=yes -o ConnectTimeout=5" "$LOCAL_DIR" "$DEST"
[ -n "$DRY" ] && exit 0
CURL=(curl -fsS -o /dev/null --cacert "$CA_CERT"); [ -n "$RESOLVE" ] && CURL+=(--resolve "$RESOLVE")
"${CURL[@]}" "$SITE_URL" || { echo "ОШИБКА: ресурс недоступен" >&2; exit 1; }
echo "OK $(git -C "$ROOT" rev-parse --short HEAD)"
