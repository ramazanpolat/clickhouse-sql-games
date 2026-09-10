#!/usr/bin/env bash
# Removes the games (databases and their SQL functions) from a ClickHouse server.
#
#   ./uninstall.sh [wordle|guess_number|all] [-- <clickhouse-client args>]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/client.sh"
split_args "$@"; set -- ${OWN[@]+"${OWN[@]}"}

case ${1:-all} in
    -h|--help)            sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    all)                  GAMES=(wordle guess_number) ;;
    wordle|guess_number)  GAMES=("$1") ;;
    *) echo "Unknown game '$1'. Use wordle, guess_number or all." >&2; exit 1 ;;
esac

ch_check
for game in "${GAMES[@]}"; do
    echo "Removing $game ..."
    ch --multiquery < "$ROOT/$game/drop-game.sql"
done
echo "Done."
