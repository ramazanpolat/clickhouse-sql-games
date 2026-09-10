#!/usr/bin/env bash
# Wordle solver. Needs only the clickhouse binary (runs clickhouse-local, no server).
#
#   ./solve.sh <gray-letters> <yellow+green-letters> [<green-pattern>]
#
#   ./solve.sh adieu rst            # a,d,i,e,u excluded; r,s,t somewhere in the word
#   ./solve.sh dur ae _a__e         # plus: A is 2nd letter, E is 5th
#   ./solve.sh "" aer               # nothing excluded yet
set -euo pipefail
if [[ ${1-} == -h || ${1-} == --help ]]; then sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0; fi
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v clickhouse >/dev/null 2>&1; then CH=(clickhouse local)
elif command -v clickhouse-local >/dev/null 2>&1; then CH=(clickhouse-local)
else echo "clickhouse binary not found (https://clickhouse.com/docs/install)" >&2; exit 1; fi
"${CH[@]}" \
    --param_black="${1-}" \
    --param_white="${2-}" \
    --param_pattern="${3-}" \
    --param_words="$DIR/sgb-words.txt" \
    --queries-file "$DIR/solver.sql" \
    --format PrettyCompactMonoBlock
