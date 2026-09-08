#!/usr/bin/env bash
# Nightly dump of Metabase's OWN app database (dashboards/questions/users).
# The telemetry database is DO-managed and backs itself up; this container's
# volume does not, so snapshot it.
#   install:  cp backup.sh /usr/local/bin/metabase-backup.sh && chmod +x $_
#   cron:     0 4 * * * root /usr/local/bin/metabase-backup.sh
set -euo pipefail
COMPOSE=/opt/metabase/docker-compose.yml
OUT=/var/backups/metabase
mkdir -p "$OUT"
docker compose -f "$COMPOSE" exec -T db pg_dump -U metabase metabase \
  | gzip > "$OUT/metabase-$(date +%F).sql.gz"
find "$OUT" -name 'metabase-*.sql.gz' -mtime +14 -delete
