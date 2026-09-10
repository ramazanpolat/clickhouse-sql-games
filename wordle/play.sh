#!/usr/bin/env bash
# Single-terminal way to play wordle: shows the board, reads your move, inserts it for you.
#
#   ./play.sh [-- <clickhouse-client args>]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../lib/client.sh"
split_args "$@"
ch_check >/dev/null
BOARD=$(< "$DIR/watch.sql")
while :; do
    printf '\033[2J\033[H'; ch --query "$BOARD"; echo
    read -r -p "> " move || { echo; break; }
    [[ -z $move ]] && continue
    [[ $move == q || $move == quit || $move == exit ]] && break
    ch --param_move="$move" --query "INSERT INTO wordle.input SELECT {move:String}"
done
