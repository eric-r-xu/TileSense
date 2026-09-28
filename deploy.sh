#!/usr/bin/env bash
# Reviewed deployment driver. See DEPLOYMENT_GUIDE.md.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
case "${1:-all}" in
  all|client|ingest|mp|migrate|geoip|setup-client|rollback-client|rollback-ingest|rollback-mp) ;;
  *) echo 'Usage: deploy.sh [all|client|ingest|mp|migrate|geoip|setup-client|rollback-client|rollback-ingest|rollback-mp RELEASE]' >&2; exit 2 ;;
esac
if [[ ! -f deploy.env ]]; then
  echo 'Missing deploy.env: cp deploy.env.example deploy.env, then fill it in (see DEPLOYMENT_GUIDE.md).' >&2
  exit 1
fi
set -a
# shellcheck source=/dev/null
source deploy.env
set +a
exec python3 server/deploy/deploy.py "$@"
