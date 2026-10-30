#!/bin/sh
# Mirrors s3://$BUCKET into a new release directory and points $SITE_DIR at it.
# nginx serves $SITE_DIR, so a request never sees a half-finished sync.
#   sync.sh once  - one sync, exits non-zero on failure
#   sync.sh loop  - sync every $SYNC_INTERVAL_SECONDS, forever

set -u

# shellcheck source=scripts/log.sh
. /usr/local/lib/cdp-api-docs/log.sh

SITE_DIR=${SITE_DIR:-/srv/site}
# Where aws s3 sync writes. Sync is slow and in-place; files appear/disappear
# mid-run. You don't want nginx reading that.
STAGING_DIR=${STAGING_DIR:-/srv/staging}
RELEASES_DIR=${RELEASES_DIR:-/srv/releases}

publish_release() {
  release="$RELEASES_DIR/$(date -u +%Y%m%dT%H%M%S)-$1"

  # Hard links: cheap, and aws s3 sync replaces files by rename, so a published
  # release never changes under nginx.
  cp -al "$STAGING_DIR" "$release" || return 1
  ln -s "$release" "$SITE_DIR.next" && mv -fT "$SITE_DIR.next" "$SITE_DIR" || return 1

  # Keep the previous release for requests still being served from it.
  # shellcheck disable=SC2012
  ls -1d "$RELEASES_DIR"/* | sort -r | tail -n +3 | while read -r old; do
    rm -rf "$old"
  done
}

sync_once() {
  started=$(date +%s)
  output=$(mktemp)

  # --exact-timestamps: without it, aws s3 sync skips same-size overwrites
  # (size+mtime only; no content/ETag compare — see AWS CLI sync docs).
  if ! aws s3 sync "s3://$BUCKET" "$STAGING_DIR" --delete --exact-timestamps --no-progress >"$output" 2>&1; then
    log error s3-sync "Sync from s3://$BUCKET failed: $(tail -n 5 "$output")"
    rm -f "$output"
    return 1
  fi

  changes=$(( $(wc -l <"$output") ))
  rm -f "$output"
  # sync --delete removes files but leaves their folders behind.
  find "$STAGING_DIR" -mindepth 1 -type d -empty -delete

  if [ "$changes" -eq 0 ] && [ -e "$SITE_DIR" ]; then
    return 0
  fi

  if ! publish_release "$1"; then
    log error s3-sync "Could not publish release for s3://$BUCKET"
    return 1
  fi

  log info s3-sync "Synced s3://$BUCKET: $changes change(s) in $(( $(date +%s) - started ))s"
}

mkdir -p "$STAGING_DIR" "$RELEASES_DIR"

case "${1:-}" in
  once)
    sync_once 0
    ;;
  loop)
    count=1
    while true; do
      sleep "$SYNC_INTERVAL_SECONDS"
      sync_once "$count"
      count=$((count + 1))
    done
    ;;
  *)
    echo "usage: $0 once|loop" >&2
    exit 2
    ;;
esac
