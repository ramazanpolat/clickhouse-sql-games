#!/usr/bin/env bash
# Live board for guess_number. Keep it running in one terminal while you INSERT your moves from another.
#
#   ./watch.sh [-- <clickhouse-client args>]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../lib/client.sh"
split_args "$@"
ch_check >/dev/null
BOARD=$(< "$DIR/watch.sql")
while :; do
    out=$(ch --query "$BOARD")
    printf '\033[2J\033[H'; printf '%s\n' "$out"
    sleep 1
done
