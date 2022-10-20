DROP DATABASE IF EXISTS guess_number;
CREATE DATABASE guess_number;

USE guess_number;

CREATE TABLE state
(
    key UInt8 MATERIALIZED 1,
    down UInt16,
    up UInt16,
    try UInt16,
    guess ALIAS intDiv(up + down, 2)
)
ENGINE = EmbeddedRocksDB
PRIMARY KEY key;

INSERT INTO state(down,up,try) VALUES(1,100,0);

CREATE TABLE input
(
    `s` String
)
ENGINE = Memory;

CREATE TABLE output
(
    `dt` DateTime MATERIALIZED now(),
    `s` String
)
ENGINE = Memory;

CREATE MATERIALIZED VIEW state_mv1 TO state AS
WITH (
        SELECT (down, up, guess, try)
        FROM state
    ) AS my_state
SELECT
    if(lower(s) = 'up', my_state.3, my_state.1) AS down,
    if(lower(s) = 'up', my_state.2, my_state.3) AS up,
    1 + my_state.4 as try
FROM input
WHERE lower(s)='up' or lower(s)='down';

CREATE MATERIALIZED VIEW state_mv2 TO state AS
WITH
	extractAll(s,'\d+') as numbers,
	length(numbers)=2 AS has_numbers,
	if(has_numbers,toInt32OrZero(numbers[1]),0) as number1,
	if(has_numbers,toInt32OrZero(numbers[2]),0) as number2
SELECT number1 as down, number2 as up, 0 as try
FROM input
WHERE has_numbers and number1 < number2;

CREATE MATERIALIZED VIEW output_mv TO output AS
WITH 
	format('New game between {0} and {1}. Is it {2}?', down::String, up::String, guess::String) as if_new_game,
	format('It is definitely {0}!', guess::String) as if_last_number,
	format('My guess is {0}', guess::String) as normal_guess,
	'You are cheating!' as cheating
SELECT 
	multiIf(
	try=0,
		if_new_game,
	try>0 AND down+1=guess AND guess+1=up,
		if_last_number,
	guess <= down OR guess >=up,
		cheating,
	normal_guess) as s
FROM state;

SET allow_experimental_live_view=1;

CREATE LIVE VIEW game AS
WITH argMax((dt, s), dt) AS line
SELECT
    splitByChar(' ',line.1::String)[2] AS time,
    line.2 AS message
FROM output
WHERE dt > (now() - 5);

SELECT '`Guess the number` game created successfully.'

