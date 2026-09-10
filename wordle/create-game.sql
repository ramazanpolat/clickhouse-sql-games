-- Wordle in pure ClickHouse SQL.
--
-- Data flow (all triggered by INSERTs into wordle.input):
--
--   input (Null) --MV--> history (MergeTree, every move ever) --MV--> games (EmbeddedRocksDB, one row: current state)
--
-- Run via ../install.sh, which also loads the word list and starts the first game.
-- Everything is fully qualified so this file works over any interface (client stdin, HTTP, fiddle).
-- Re-running it gives you a clean slate: the database (and all game history) is recreated.

DROP DATABASE IF EXISTS wordle;
CREATE DATABASE wordle;

-- Dictionary. Populated by install.sh from sgb-words.txt (lowercase, one word per line).
CREATE TABLE IF NOT EXISTS wordle.words
(
    word String
)
ENGINE = MergeTree
ORDER BY word;

-- Where the player types. Nothing is stored here; the materialized views below react to each INSERT.
CREATE TABLE IF NOT EXISTS wordle.input
(
    s String
)
ENGINE = Null;

-- Every move of every game. try = 0 is the "new game" row.
CREATE TABLE IF NOT EXISTS wordle.history
(
    game_id    UInt32,
    try        UInt8,
    target_str String,
    input_str  String,
    ts         DateTime64(3) MATERIALIZED now64(3)
)
ENGINE = MergeTree
ORDER BY (game_id, try);

-- Current state: a single row, overwritten on every move thanks to the constant primary key.
CREATE TABLE IF NOT EXISTS wordle.games
(
    key        UInt8 MATERIALIZED 1,
    game_id    UInt32,
    try        UInt8,
    target_str String,
    input_str  String
)
ENGINE = EmbeddedRocksDB
PRIMARY KEY key;

-- ---------------------------------------------------------------------------
-- Functions (SQL UDFs are server-global, hence the wordle_ prefix)
-- ---------------------------------------------------------------------------

-- Wordle scoring with correct duplicate-letter handling.
-- targ/inp are arrays of 5 single-character strings; returns 2 = green, 1 = yellow, 0 = gray per position.
-- A letter is yellow only while the target still has unclaimed copies of it: copies matched green anywhere,
-- or already marked yellow further left, are used up first.
CREATE OR REPLACE FUNCTION wordle_compare AS (targ, inp) ->
    arrayMap(i -> multiIf(
        inp[i] = targ[i], 2,
        countEqual(targ, inp[i])
            - arrayCount(j -> inp[j] = inp[i] AND inp[j]  = targ[j], [1, 2, 3, 4, 5])
            - arrayCount(k -> k < i AND inp[k] = inp[i] AND inp[k] != targ[k], [1, 2, 3, 4, 5]) > 0, 1,
        0), [1, 2, 3, 4, 5]);

-- Renders a guess as terminal tiles: green / yellow / gray background, ANSI escapes.
CREATE OR REPLACE FUNCTION wordle_colored AS (targ, inp) ->
    arrayStringConcat(
        arrayMap((c, m) -> concat(char(27), '[1;97;', ['100', '43', '42'][m + 1], 'm ', c, ' ', char(27), '[0m'),
                 splitByString('', inp),
                 wordle_compare(splitByString('', targ), splitByString('', inp))),
        ' ');

-- Empty string when the dictionary has not been loaded yet (watch.sql turns that into a hint).
CREATE OR REPLACE FUNCTION wordle_random_word AS () -> (SELECT upper(any(word)) FROM (SELECT word FROM wordle.words ORDER BY rand() LIMIT 1));

-- Accessors for the single current-state row.
CREATE OR REPLACE FUNCTION wordle_game_id   AS () -> (SELECT max(game_id) FROM wordle.games);
CREATE OR REPLACE FUNCTION wordle_try       AS () -> (SELECT max(try) FROM wordle.games);
CREATE OR REPLACE FUNCTION wordle_target    AS () -> (SELECT any(target_str) FROM wordle.games);
CREATE OR REPLACE FUNCTION wordle_game_over AS () -> (SELECT count() > 0 FROM wordle.games WHERE try >= 6 OR (try > 0 AND input_str = target_str));

-- ---------------------------------------------------------------------------
-- Game logic
-- ---------------------------------------------------------------------------

-- "new game" (any text containing both words) opens the next game with a fresh random target.
CREATE MATERIALIZED VIEW IF NOT EXISTS wordle.history_new_game_mv TO wordle.history AS
SELECT
    wordle_game_id() + 1 AS game_id,
    0                    AS try,
    wordle_random_word() AS target_str,
    ''                   AS input_str
FROM wordle.input
WHERE lower(s) LIKE '%new%' AND lower(s) LIKE '%game%';

-- Any 5-letter word is a guess, as long as the current game is still running.
CREATE MATERIALIZED VIEW IF NOT EXISTS wordle.history_guess_mv TO wordle.history AS
SELECT
    wordle_game_id()  AS game_id,
    wordle_try() + 1  AS try,
    wordle_target()   AS target_str,
    upper(s)          AS input_str
FROM wordle.input
WHERE match(s, '^[A-Za-z]{5}$') AND wordle_game_id() > 0 AND NOT wordle_game_over();

-- Every history row becomes the new current state.
CREATE MATERIALIZED VIEW IF NOT EXISTS wordle.games_mv TO wordle.games AS
SELECT game_id, try, target_str, input_str
FROM wordle.history;
