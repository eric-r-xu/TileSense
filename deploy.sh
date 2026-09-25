#!/usr/bin/env bash
# Reviewed deployment driver. See DEPLOYMENT_CHEATSHEET.md.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
case "${1:-all}" in
  all|client|ingest|mp|migrate|geoip|setup-client|rollback-client) ;;
  *) echo 'Usage: deploy.sh [all|client|ingest|mp|migrate|geoip|setup-client|rollback-client RELEASE]' >&2; exit 2 ;;
esac
if [[ ! -f deploy.env ]]; then
  echo 'Missing deploy.env; see server/DEPLOYMENT.md.' >&2
  exit 1
fi
set -a
# shellcheck source=/dev/null
source deploy.env
set +a
exec python3 server/deploy/deploy.py "$@"
