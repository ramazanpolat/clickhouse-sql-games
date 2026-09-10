# Sourced by the scripts in this repo. Resolves the ClickHouse client into the CH array.
#
#   CLICKHOUSE_CLIENT   full client command, overrides autodetection, e.g.
#                       CLICKHOUSE_CLIENT="docker compose exec -T clickhouse clickhouse-client"
#   extra arguments     everything after "--" on the script's command line is appended,
#                       e.g. ./install.sh wordle -- --host ch.example.com --password secret
#
# Usage after sourcing:  ch --query "SELECT 1"

if [[ -n ${CLICKHOUSE_CLIENT-} ]]; then
    read -r -a CH <<<"$CLICKHOUSE_CLIENT"
elif command -v clickhouse-client >/dev/null 2>&1; then
    CH=(clickhouse-client)
elif command -v clickhouse >/dev/null 2>&1; then
    CH=(clickhouse client)
else
    echo "clickhouse-client not found." >&2
    echo "Install ClickHouse (https://clickhouse.com/docs/install) or start one with: docker compose up -d" >&2
    exit 1
fi

# (the ${arr[@]+"${arr[@]}"} form keeps `set -u` happy on the bash 3.2 that ships with macOS)
CH_ARGS=()
ch() { "${CH[@]}" ${CH_ARGS[@]+"${CH_ARGS[@]}"} "$@"; }

# Splits "<own args> -- <client args>": own args land in OWN (use `set -- ${OWN[@]+"${OWN[@]}"}`), client args in CH_ARGS.
split_args() {
    OWN=(); CH_ARGS=()
    while [[ $# -gt 0 ]]; do
        if [[ $1 == -- ]]; then shift; CH_ARGS=("$@"); break; fi
        OWN+=("$1"); shift
    done
}

# Fails fast with a readable message when the server is unreachable.
ch_check() {
    local v
    if ! v=$(ch --query "SELECT version()" 2>&1); then
        echo "Cannot reach ClickHouse with: ${CH[*]} ${CH_ARGS[*]-}" >&2
        echo "$v" >&2
        exit 1
    fi
    echo "ClickHouse $v"
}
