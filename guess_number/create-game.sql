-- "Guess the number" in pure ClickHouse SQL: you pick a number, ClickHouse finds it by bisection.
--
-- Data flow (all triggered by INSERTs into guess_number.input):
--
--   input (Null) --MV--> history (MergeTree, every move ever) --MV--> state (EmbeddedRocksDB, one row: current state)
--
-- Everything is fully qualified so this file works over any interface (client stdin, HTTP, fiddle).
-- Re-running it gives you a clean slate: the database (and all game history) is recreated.

DROP DATABASE IF EXISTS guess_number;
CREATE DATABASE guess_number;

-- Where the player types: 'new game', 'new game 1 1000', 'up', 'down', 'yes'.
CREATE TABLE guess_number.input
(
    s String
)
ENGINE = Null;

-- Every move of every game. try = 0 is the "new game" row. lo/hi are the inclusive bounds still possible.
CREATE TABLE guess_number.history
(
    game_id UInt32,
    try     UInt16,
    lo      Int64,
    hi      Int64,
    done    Bool,
    said    String,
    message String,
    ts      DateTime64(3) MATERIALIZED now64(3)
)
ENGINE = MergeTree
ORDER BY (game_id, try);

-- Current state: a single row, overwritten on every move thanks to the constant primary key.
CREATE TABLE guess_number.state
(
    key     UInt8 MATERIALIZED 1,
    game_id UInt32,
    try     UInt16,
    lo      Int64,
    hi      Int64,
    done    Bool
)
ENGINE = EmbeddedRocksDB
PRIMARY KEY key;

-- ---------------------------------------------------------------------------
-- Functions (SQL UDFs are server-global, hence the gn_ prefix)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION gn_guess AS (lo, hi) -> intDiv(lo + hi, 2);

CREATE OR REPLACE FUNCTION gn_message AS (lo, hi, try, done) -> multiIf(
    done,     format('Got it in {0} guesses! Say "new game" to play again.', toString(try)),
    try = 0,  format('New game between {0} and {1}. Is it {2}?', toString(lo), toString(hi), toString(gn_guess(lo, hi))),
    lo > hi,  'You are cheating! Say "new game" to play again.',
    lo = hi,  format('It is definitely {0}!', toString(lo)),
              format('My guess is {0}. up, down or yes?', toString(gn_guess(lo, hi))));

-- Accessor for the single current-state row. Aggregates so that an empty table yields zeros, never NULL
-- (a NULL scalar would make the materialized views below fail on the first INSERT).
CREATE OR REPLACE FUNCTION gn_state AS () -> (SELECT (max(game_id), max(try), any(lo), any(hi), any(done)) FROM guess_number.state);

-- ---------------------------------------------------------------------------
-- Game logic
-- ---------------------------------------------------------------------------

-- "new game" opens a 1..100 game; "new game 1 1000" (any text with two numbers) sets the range.
CREATE MATERIALIZED VIEW guess_number.history_new_game_mv TO guess_number.history AS
WITH
    arrayMap(x -> toInt64OrZero(x), extractAll(s, '-?\\d+')) AS numbers,
    length(numbers) = 2 AND numbers[1] < numbers[2]         AS has_range,
    if(has_range, numbers[1], 1)                            AS new_lo,
    if(has_range, numbers[2], 100)                          AS new_hi
SELECT
    tupleElement(gn_state(), 1) + 1     AS game_id,
    0                                   AS try,
    new_lo                              AS lo,
    new_hi                              AS hi,
    false                               AS done,
    s                                   AS said,
    gn_message(new_lo, new_hi, 0, false) AS message
FROM guess_number.input
WHERE has_range OR (lower(s) LIKE '%new%' AND lower(s) LIKE '%game%');

-- "up" / "down" (or higher / lower) narrows the range; "yes" ends the game.
CREATE MATERIALIZED VIEW guess_number.history_move_mv TO guess_number.history AS
WITH
    gn_state()                          AS st,
    tupleElement(st, 1)                 AS game_id_,
    tupleElement(st, 2)                 AS try_,
    tupleElement(st, 3)                 AS lo_,
    tupleElement(st, 4)                 AS hi_,
    tupleElement(st, 5)                 AS done_,
    lower(trim(s))                      AS word,
    word IN ('up', 'higher', 'more', 'bigger')   AS is_up,
    word IN ('down', 'lower', 'less', 'smaller') AS is_down,
    word IN ('yes', 'correct', 'right')          AS is_yes,
    gn_guess(lo_, hi_)                  AS guess,
    if(is_up, guess + 1, lo_)           AS new_lo,
    if(is_down, guess - 1, hi_)         AS new_hi
SELECT
    game_id_                            AS game_id,
    try_ + 1                            AS try,
    new_lo                              AS lo,
    new_hi                              AS hi,
    is_yes                              AS done,
    s                                   AS said,
    gn_message(new_lo, new_hi, try_ + 1, is_yes) AS message
FROM guess_number.input
WHERE (is_up OR is_down OR is_yes) AND game_id_ > 0 AND NOT done_ AND lo_ <= hi_;

-- Every history row becomes the new current state.
CREATE MATERIALIZED VIEW guess_number.state_mv TO guess_number.state AS
SELECT game_id, try, lo, hi, done
FROM guess_number.history;
