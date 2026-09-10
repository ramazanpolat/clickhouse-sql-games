# Wordle

Guess the five-letter word in six tries. After each guess every letter is coloured: green is the
right letter in the right place, yellow is in the word but elsewhere, gray is not in the word.
Repeated letters are scored the way the real game does it, so a second `E` only turns yellow if the
target has a second `E` to give.

## Play

From the repository root, once:

```bash
./install.sh wordle
```

Then either the one-terminal way:

```bash
./wordle/play.sh
```

or the SQL way, board in one terminal and `clickhouse-client` in another:

```bash
./wordle/watch.sh
```

```sql
INSERT INTO wordle.input VALUES ('crane');      -- a guess: any five letters
INSERT INTO wordle.input VALUES ('new game');   -- start over (any text containing "new" and "game")
```

Guesses are not checked against a dictionary. The target is drawn from `sgb-words.txt`: Donald
Knuth's list of 5757 five-letter English words from the Stanford GraphBase.

## Files

| File | Purpose |
|------|---------|
| `create-game.sql` | Database, tables, functions and materialized views. Drops and recreates the `wordle` database. |
| `drop-game.sql` | Removes everything `create-game.sql` made, functions included. |
| `watch.sql` | One `SELECT` that renders the current board. |
| `watch.sh`, `play.sh` | Poll the board / add a prompt. Both accept `-- <clickhouse-client args>`. |
| `solver.sql`, `solve.sh` | The solver, see below. |
| `sgb-words.txt` | The word list, loaded into `wordle.words` by `install.sh`. |

## Under the hood

Tables:

- `wordle.input` (`Null`): where you type. Nothing is stored.
- `wordle.history` (`MergeTree`): one row per move, `try = 0` being the "new game" row.
- `wordle.games` (`EmbeddedRocksDB`, `PRIMARY KEY key` with `key MATERIALIZED 1`): the current
  game, always exactly one row.
- `wordle.words`: the dictionary.

Materialized views, all triggered by an insert into `input`:

- `history_new_game_mv`: matches `%new%game%`, writes a `try = 0` row with a fresh random target.
- `history_guess_mv`: matches `^[A-Za-z]{5}$`, writes the next try with the current target, unless
  the game is already won or on its sixth try.
- `games_mv`: copies every `history` row into `games`, which overwrites the single state row.

Functions (prefixed `wordle_`, since SQL UDFs are server-global):

- `wordle_compare(target, guess)` takes two arrays of single characters and returns
  `[2, 1, 0, ...]` per position. A letter is yellow only while the target still has an unclaimed copy
  of it: copies matched green anywhere, or already marked yellow further left, are used up first.
  That is done with `countEqual` and two `arrayCount` lambdas over the positions.
- `wordle_colored(target, guess)` turns that into ANSI-coloured tiles.
- `wordle_random_word()`, `wordle_game_id()`, `wordle_try()`, `wordle_target()`,
  `wordle_game_over()`: scalar subqueries on `words` and `games`, written with aggregates so an
  empty table yields defaults rather than `NULL`.

## Solver

The "cheater" from the talk: give it what the game told you and it lists every word that still fits.
It runs on `clickhouse-local`, so it needs only the ClickHouse binary, no server.

```bash
./wordle/solve.sh <gray-letters> <yellow-and-green-letters> [<green-pattern>]

./wordle/solve.sh adieu rst          # a d i e u are gray; r s t are somewhere in the word
./wordle/solve.sh dur ae _a__e       # ...and A is the 2nd letter, E the 5th
./wordle/solve.sh "" aer             # nothing ruled out yet
```

The same query is on [ClickHouse Fiddle](https://fiddle.clickhouse.com/229101f4-a8f0-45cc-be7f-33e916805954)
(short link: https://bit.ly/sql-games) with the word list read straight from GitHub.
