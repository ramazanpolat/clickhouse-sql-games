#!/usr/bin/env bash
# Installs the games into a ClickHouse server and starts a first round of each.
#
#   ./install.sh [wordle|guess_number|all] [-- <clickhouse-client args>]
#
#   ./install.sh                                          # both games, local server
#   ./install.sh wordle -- --host ch.example.com --secure  # remote server
#   CLICKHOUSE_CLIENT="docker compose exec -T clickhouse clickhouse-client" ./install.sh
#
# Re-running reinstalls from scratch (databases are dropped and recreated).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/client.sh"
split_args "$@"; set -- ${OWN[@]+"${OWN[@]}"}

case ${1:-all} in
    -h|--help)            sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    all)                  GAMES=(wordle guess_number) ;;
    wordle|guess_number)  GAMES=("$1") ;;
    *) echo "Unknown game '$1'. Use wordle, guess_number or all." >&2; exit 1 ;;
esac

ch_check
for game in "${GAMES[@]}"; do
    echo "Installing $game ..."
    ch --multiquery < "$ROOT/$game/create-game.sql"
    if [[ $game == wordle ]]; then
        ch --query "INSERT INTO wordle.words FORMAT LineAsString" < "$ROOT/wordle/sgb-words.txt"
        echo "  loaded $(ch --query "SELECT count() FROM wordle.words") words"
    fi
    ch --query "INSERT INTO $game.input VALUES ('new game')"
done

cat <<EOF

Done. A round of each game is already waiting for you.

  One terminal:   ./wordle/play.sh          ./guess_number/play.sh
  Or the SQL way: ./wordle/watch.sh   +   ${CH[*]} ${CH_ARGS[*]-}
                  INSERT INTO wordle.input VALUES ('crane');
                  INSERT INTO guess_number.input VALUES ('up');
EOF
