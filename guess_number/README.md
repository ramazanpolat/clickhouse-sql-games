# Guess the number

Think of a number. ClickHouse guesses, you answer `up` (mine is higher), `down` (mine is lower) or
`yes`, and it closes in by bisection: seven answers at most for 1..100.

## Play

From the repository root, once:

```bash
./install.sh guess_number
```

Then either the one-terminal way:

```bash
./guess_number/play.sh
```

```
GUESS THE NUMBER  --  game #1

  New game between 1 and 100. Is it 50?
  > up
  My guess is 75. up, down or yes?
  > down
  My guess is 62. up, down or yes?
  > yes
  Got it in 3 guesses! Say "new game" to play again.
```

or the SQL way, transcript in one terminal and `clickhouse-client` in another:

```bash
./guess_number/watch.sh
```

```sql
INSERT INTO guess_number.input VALUES ('up');              -- or higher / more / bigger
INSERT INTO guess_number.input VALUES ('down');            -- or lower / less / smaller
INSERT INTO guess_number.input VALUES ('yes');             -- or correct / right
INSERT INTO guess_number.input VALUES ('new game');        -- 1..100
INSERT INTO guess_number.input VALUES ('new game 1 1000'); -- any text with two numbers sets the range
```

Answer `up` when you should have said `down` and the range runs out: "You are cheating!"

## Files

| File | Purpose |
|------|---------|
| `create-game.sql` | Database, tables, functions and materialized views. Drops and recreates the `guess_number` database. |
| `drop-game.sql` | Removes everything `create-game.sql` made, functions included. |
| `watch.sql` | One `SELECT` that renders the transcript of the current game. |
| `watch.sh`, `play.sh` | Poll the transcript / add a prompt. Both accept `-- <clickhouse-client args>`. |

## Under the hood

Tables:

- `guess_number.input` (`Null`): where you type. Nothing is stored.
- `guess_number.history` (`MergeTree`): one row per move with the bounds after it, what you said
  and what ClickHouse replied.
- `guess_number.state` (`EmbeddedRocksDB`, constant primary key): the current game, one row:
  `lo` and `hi` are the inclusive bounds still possible, `try` counts your answers, `done` is set
  once you say `yes`.

Materialized views, all triggered by an insert into `input`:

- `history_new_game_mv`: `extractAll(s, '-?\d+')` pulls two numbers out of the text for a custom
  range; "new game" without numbers means 1..100.
- `history_move_mv`: `up` moves `lo` to `guess + 1`, `down` moves `hi` to `guess - 1`, `yes` marks
  the game done. Ignored once a game is over or the bounds have crossed.
- `state_mv`: copies every `history` row into `state`, which overwrites the single state row.

Functions (prefixed `gn_`, since SQL UDFs are server-global):

- `gn_guess(lo, hi)` is `intDiv(lo + hi, 2)`.
- `gn_message(lo, hi, try, done)` writes the reply: new game, a normal guess, "It is definitely N!"
  when `lo = hi`, cheating when `lo > hi`, and the tally when you say `yes`.
- `gn_state()` returns the state row as a tuple of aggregates, so an empty table yields zeros and
  the very first insert does not trip over a `NULL`.
