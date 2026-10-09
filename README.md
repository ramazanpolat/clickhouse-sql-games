# ClickHouse SQL Games

Games written in nothing but ClickHouse SQL. There is no application code: you play by
`INSERT`ing into a table, materialized views work out the next move, a one-row
`EmbeddedRocksDB` table holds the state, and the board is a `SELECT`.

| Game | What it is |
|------|------------|
| [Wordle](wordle/) | The word game, with green / yellow / gray tiles drawn in your terminal |
| [Guess the number](guess_number/) | Think of a number; ClickHouse finds it by bisection while you answer `up` or `down` |
| [Wordle solver](wordle/#solver) | Bonus: lists every word that fits the clues you have so far |

Written for the talk **ClickHouse SQL Games** at the Istanbul ClickHouse Meetup on 2022-10-21,
organised by [Altinity](https://altinity.com/) and [P.I. Works](https://piworks.net/). The slides are
in [`docs/`](docs/clickhouse-istanbul-meetup-sql-games.pdf) and on
[SlideShare](https://www.slideshare.net/rpolat/clickhouse-sql-games). Refreshed in 2026 for current
ClickHouse; tested with 26.7 and 26.8.

## Quick start

You need `clickhouse-client` and a ClickHouse server, or Docker. Tested with ClickHouse 26.7 and
26.8; any release with the new analyzer on by default (24.3+) should behave the same.

### With a ClickHouse server you already have

```bash
./install.sh          # installs both games and starts a round of each
./wordle/play.sh      # play
```

### With Docker

```bash
docker compose up -d  # ClickHouse with both games installed, on localhost:8123 / :9000
./wordle/play.sh      # with a local clickhouse-client, or:
CLICKHOUSE_CLIENT="docker compose exec -T clickhouse clickhouse-client" ./wordle/play.sh
```

`play.sh` is a thin wrapper: it prints the board, reads a line, inserts it. The real experience is
doing that yourself from the SQL client, with the board in a second terminal:

```bash
./wordle/watch.sh                                  # terminal 1: the board, refreshed every second
```

```sql
-- terminal 2: clickhouse-client
INSERT INTO wordle.input VALUES ('crane');
INSERT INTO wordle.input VALUES ('new game');
```

### Talking to another server

Every script accepts `clickhouse-client` arguments after `--`, or a complete client command in
`CLICKHOUSE_CLIENT`:

```bash
./install.sh wordle -- --host ch.example.com --secure --password '...'
CLICKHOUSE_CLIENT="clickhouse-client --host 10.0.0.5" ./wordle/watch.sh
```

### Uninstall

```bash
./uninstall.sh        # drops both databases and their SQL functions
```

## How it works

Both games share one design:

```
INSERT INTO <game>.input          Null table: stores nothing, exists to fire the views below
        |
        |   materialized views: parse the text, read the current state, compute the move
        v
<game>.history                    MergeTree: every move of every game
        |
        |   materialized view
        v
<game>.state                      EmbeddedRocksDB with a constant primary key: exactly one row
```

- The views get at the current state through SQL user-defined functions (`wordle_target()`,
  `gn_state()`, ...) that wrap scalar subqueries on the state table.
- The state table's primary key is a `MATERIALIZED 1` column, so every insert overwrites the single
  row: an upsert in one line of DDL.
- `watch.sql` renders the board from `history` and `state`. `watch.sh` polls it; `play.sh` adds a prompt.

Each game's README walks through its SQL.

### What changed since the 2022 talk

ClickHouse moved on, and the original SQL no longer runs on current releases:

- `LIVE VIEW`, which *Guess the number* used as its display, has been removed. Both games now
  render with a plain `SELECT` that a shell loop polls.
- A materialized view whose **source** is an `EmbeddedRocksDB` table no longer fires (verified on
  26.7). The flow used to be `input -> state -> history`; it is now `input -> history -> state`.
- The new query analyzer folds scalar subqueries while *creating* a materialized view, which turned
  `rand() % (SELECT count() FROM words)` into a division by zero at DDL time.
- Functions were given `wordle_` / `gn_` prefixes: SQL UDFs are global to the server, and names like
  `compare` or `clear` are not yours to take.

The 2022 version is in the git history if you want the SQL exactly as presented in the talk.

## Repository layout

```
install.sh, uninstall.sh   install / remove one game or both on any server
docker-compose.yml         throwaway server with the games preinstalled (see docker/)
lib/client.sh              shared client resolution used by every script
wordle/                    create-game.sql, watch.sql, watch.sh, play.sh, solver, word list, README
guess_number/              create-game.sql, watch.sql, watch.sh, play.sh, README
docs/                      talk slides
```

## Contributing

Wrote a game in ClickHouse SQL? Open a pull request. Keep it in its own directory with a
`create-game.sql`, a `drop-game.sql` and a `watch.sql`, and `install.sh` can pick it up.

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).

Relicensed from MIT to Apache-2.0 on 2026-10-10; commits before that date remain available under MIT as well.
