# clickhouse-sql-games

This repository demonstrates the power of [ClickHouse](https://clickhouse.com/) by showcasing two games that leverage native ClickHouse functions through SQL.

As a bonus, a [ClickHouse fiddle](https://fiddle.clickhouse.com/229101f4-a8f0-45cc-be7f-33e916805954) is provided to assist in solving the Wordle game.

This repo created to accompany the talk [ClickHouse SQL Games](https://www.slideshare.net/rpolat/clickhouse-sql-games) given at [Istanbul ClickHouse Meetup](https://altinity.com/events/istanbul-clickhouse-meetup-october-21), organized by [Altinity](https://altinity.com/) and [P.I. Works](https://piworks.net/) in 2022-10-21 and presented by the author of the code.

## Game 1: Guess the number
In this game, ClickHouse tries to guess the number you've randomly picked between 1 and 100. For each guess, you direct ClickHouse by inserting `up` or `down` into the `input` table. Then ClickHouse responses with another guess. The game itself as you guessed is the classic [guess the number](https://math.stackexchange.com/questions/1773361/guess-my-number-game-plus-minus) game. Game input is provided by inserting into the `input` table. And the output is captured by a SELECT SQL in a Live View. The game is developed using 100% native ClickHouse SQL and features.

## Game 2: Wordle
This game is ClickHouse adaptaion of the famous [Wordle game](https://www.nytimes.com/games/wordle/index.html). It will be interesting to see a game that needs colors to be played is displayed in terminal.

## Bonus: Wordle Cheater
You can visit https://bit.ly/sql-games to see a ClickHouse SQL code hosted on [clickhouse fiddle](https://fiddle.clickhouse.com/229101f4-a8f0-45cc-be7f-33e916805954).
Using the SQL code and combining with the response from actual game, a user can see possible solutions for Wordle.
