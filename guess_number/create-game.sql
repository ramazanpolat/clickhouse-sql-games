DROP DATABASE IF EXISTS guess_number;
CREATE DATABASE guess_number;

USE guess_number;

CREATE TABLE state
(
    `key` Int32 MATERIALIZED 1,
    `down` Int32,
    `up` Int32,
    `guess` Int32 MATERIALIZED intDiv(up + down, 2)
)
ENGINE = EmbeddedRocksDB
PRIMARY KEY key;

CREATE TABLE input
(
    `dt` DateTime64(3) MATERIALIZED now64(),
    `s` String
)
ENGINE = Memory;

CREATE TABLE output
(
    `dt` DateTime MATERIALIZED now(),
    `s` String
)
ENGINE = MergeTree ORDER BY dt;

DROP TABLE state_mv1;

CREATE MATERIALIZED VIEW state_mv1 TO state AS
WITH (
        SELECT (down, up, guess)
        FROM state
    ) AS my_state
SELECT
    if(s = 'up', my_state.3, my_state.1) AS down,
    if(s = 'up', my_state.2, my_state.3) AS up
FROM input
WHERE length(extractAll(s,'\d+')) = 0;

CREATE MATERIALIZED VIEW state_mv2 TO state AS
WITH
	extractAll(s,'\d+') as numbers, 
	length(numbers)=2 AS has_numbers, 
	if(has_numbers,toInt32OrZero(numbers[1]),0) as number1,
	if(has_numbers,toInt32OrZero(numbers[2]),0) as number2
SELECT number1 as down, number2 as up
FROM input
WHERE has_numbers and number1< number2;

CREATE MATERIALIZED VIEW output_mv TO output
SELECT format('My guess is {0}', CAST(guess, 'String')) AS s
FROM state;

SET allow_experimental_live_view=1;

CREATE LIVE VIEW game AS
WITH argMax((dt, s), dt) AS line
SELECT
    splitByChar(' ',line.1::String)[2] AS time,
    line.2 AS message
FROM output
WHERE dt > (now() - 5);
*/
--watch game;
--INSERT INTO state VALUES (1,100);
--INSERT INTO input VALUES ('up');