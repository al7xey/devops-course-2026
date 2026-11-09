#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
remote=${REMOTE:-devops}
dest=${REMOTE_DIR:-/var/www/devops-site}
url=${SITE_URL:-https://devops.local}
ca=${CA_CERT:-"$HOME/devops.crt"}
ssh_cmd=${DEPLOY_SSH:-ssh -o BatchMode=yes -o ConnectTimeout=5}
opts=(-avzi --delete --chmod=D755,F644)
case "$#:${1-}" in
  0:) ;;
  1:--dry-run) opts+=(--dry-run) ;;
  *) echo 'Usage: scripts/deploy.sh [--dry-run]' >&2; exit 1 ;;
esac
[[ -f "$root/site/index.html" ]] || { echo 'ERROR: missing site/index.html' >&2; exit 1; }
[[ -z "$(git -C "$root" status --porcelain)" ]] || { echo 'ERROR: uncommitted changes' >&2; exit 1; }
rsync "${opts[@]}" -e "$ssh_cmd" "$root/site/" "$remote:$dest/" || exit 1
[[ "${1-}" != --dry-run ]] || exit 0
curl_opts=()
if [[ -n "${CURL_RESOLVE:-}" ]]; then curl_opts+=(--resolve "$CURL_RESOLVE"); fi
curl -fsS --max-time 10 "${curl_opts[@]}" --cacert "$ca" -o /dev/null "$url" || { echo 'ERROR: HTTPS health check failed' >&2; exit 1; }
printf 'OK %s\n' "$(git -C "$root" rev-parse --short HEAD)"
