# shellcheck shell=sh
# Sourced by the other scripts. Prints one ECS JSON log line to stdout.
# Usage: log <level> <action> <message>

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n\r\t' '   '
}

log() {
  printf '{"@timestamp":"%s","log.level":"%s","message":"%s","event":{"action":"%s"}}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$(json_escape "$3")" "$2"
}
