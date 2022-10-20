DROP DATABASE IF EXISTS wordle;
CREATE DATABASE wordle;

USE wordle;

CREATE TABLE IF NOT EXISTS words
(
    id UInt16,
    `word` String
)
ENGINE = TinyLog 
AS SELECT rowNumberInAllBlocks() as id, c1 as word FROM url('https://raw.githubusercontent.com/charlesreid1/five-letter-words/master/sgb-words.txt', 'CSV') ORDER BY word;

DROP FUNCTION IF EXISTS compare;
CREATE FUNCTION IF NOT EXISTS compare AS (targ, inp) ->  arrayMap((i, c) -> multiIf(c = (targ[i]), 2, has(targ, c), 1, 0), [1,2,3,4,5], inp);

DROP FUNCTION IF EXISTS green;
CREATE FUNCTION IF NOT EXISTS green AS s -> char(27)||'[32m'||s||char(27)||'[0m';

DROP FUNCTION IF EXISTS yellow;
CREATE FUNCTION IF NOT EXISTS yellow AS s -> char(27)||'[33m'||s||char(27)||'[0m';

DROP FUNCTION IF EXISTS dark;
CREATE FUNCTION IF NOT EXISTS dark AS s -> char(27)||'[90m'||s||char(27)||'[0m';

DROP FUNCTION IF EXISTS clear;
CREATE FUNCTION IF NOT EXISTS clear AS s -> char(27)||'[2J'||s||char(27)||'[0m';

DROP FUNCTION IF EXISTS colored ;
CREATE FUNCTION IF NOT EXISTS colored AS (targ, inp) -> if(length(targ)=5 AND length(inp)=5,arrayStringConcat(arrayMap((i, c) -> multiIf(c = splitByString('',targ)[i], green(splitByString('',inp)[i]), has(splitByString('',targ), c), yellow(splitByString('',inp)[i]), dark(splitByString('',inp)[i])), [1, 2, 3, 4, 5], splitByString('',inp))),'');

DROP FUNCTION IF EXISTS last_game_id;
CREATE FUNCTION IF NOT EXISTS last_game_id AS () -> (SELECT max(game_id) FROM games);

drop FUNCTION IF EXISTS last_try;
CREATE FUNCTION IF NOT EXISTS last_try AS () -> (SELECT max(try) FROM games);

drop FUNCTION IF EXISTS target_string;
CREATE FUNCTION IF NOT EXISTS target_string AS () -> (SELECT target_str FROM games);

DROP FUNCTION IF EXISTS random_word;
CREATE FUNCTION random_word AS () -> (SELECT upper(word) as word FROM words where id = (SELECT rand() % (select count() FROM words)));

DROP TABLE IF EXISTS input;
CREATE TABLE IF NOT EXISTS input(
    s String
)
ENGINE=Null;

DROP TABLE IF EXISTS games;
CREATE TABLE IF NOT EXISTS games(
    key UInt16 MATERIALIZED 1,
    game_id UInt16,
    try UInt16,
    target_str String,
    input_str String
)
ENGINE = EmbeddedRocksDB PRIMARY KEY key;

DROP TABLE IF EXISTS output;
CREATE TABLE IF NOT EXISTS output(
    game_id UInt16,
    try UInt16,
    target_str String,
    input_str String    
) Engine=Memory;

DROP TABLE IF EXISTS output_mv;
CREATE MATERIALIZED VIEW IF NOT EXISTS output_mv TO output AS
SELECT game_id, try, target_str, input_str
FROM games;

DROP TABLE IF EXISTS games_mv1;
CREATE MATERIALIZED VIEW IF NOT EXISTS games_mv1 TO games AS
SELECT
    last_game_id()+1 as game_id,
    0 as try,
    random_word() as target_str,
    '' as input_str
FROM input 
WHERE position('new' IN lower(s)) and position('game' IN lower(s));

DROP TABLE IF EXISTS games_mv2 ;
CREATE MATERIALIZED VIEW games_mv2 TO games AS
WITH (
        SELECT (max(game_id),max(try)) AS game_try
        FROM games LIMIT 1
    ) AS my_game
SELECT
    my_game.1 as game_id,
    last_try()+1 as try,
    target_string() as target_str,
    upper(s) as input_str
FROM input 
WHERE length(s)=5;

INSERT INTO games SELECT 1 as game_id, 0 as try, random_word() as target_str, '' as input_str;

SELECT '`Wordle` game created successfully.'
