#!/bin/sh
# Container entrypoint. Takes no arguments; configured by environment variables:
#   PORT                   port nginx listens on (8085 on CDP)
#   BUCKET                 bucket holding the api docs site, required when syncing
#   SYNC_ENABLED           false serves whatever is already in /srv/site (local testing)
#   SYNC_INTERVAL_SECONDS  seconds between syncs

set -eu

# shellcheck source=scripts/log.sh
. /usr/local/lib/cdp-api-docs/log.sh

# shellcheck disable=SC2016 # envsubst takes the literal name, so nginx's own $vars are left alone
envsubst '${PORT}' </etc/nginx/nginx.conf.template >/tmp/nginx.conf

if [ "$SYNC_ENABLED" = "true" ]; then
  if [ -z "${BUCKET:-}" ]; then
    log error startup "BUCKET is not set"
    exit 1
  fi
  log info startup "Initial sync from s3://$BUCKET"
  if ! sync.sh once; then
    log error startup "Initial sync failed, exiting"
    exit 1
  fi
  sync.sh loop &
else
  log info startup "SYNC_ENABLED=$SYNC_ENABLED, serving /srv/site as is"
fi

log info startup "Serving on port $PORT"
exec nginx -c /tmp/nginx.conf -g 'daemon off;'
