# clickhouse-sql-games
This repo shows how powerful [ClickHouse](https://clickhouse.com/) is by creating 2 games only by abusing native ClickHouse functions using SQL.
As a bonus, you can use ClickHouse to solve the Wordle game.

This repo created to accompany the talk [ClickHouse SQL Games](https://www.slideshare.net/rpolat/clickhouse-sql-games) given at [Istanbul ClickHouse Meetup](https://altinity.com/events/istanbul-clickhouse-meetup-october-21), organized by [Altinity](https://altinity.com/) and [P.I. Works](https://piworks.net/) in 2022-10-21 and presented by the author of the code.

## Game 1: Guess the number
In this game, when run, ClickHouse responses in a way like it is a game engine, intercepting input of SQL and executes outputs how it is programmed to do. The output shown in terminal, typically as a resultset of SELECT query. Interestingly, the engine not only accepts SQL but also programmed in SQL. This is what makes it an interesting engine.

The game itself as you guessed is the classic [guess the number](https://math.stackexchange.com/questions/1773361/guess-my-number-game-plus-minus) game.

## Game 2: Wordle
This game not only has the same spirit of first game, but also shows different colors on the screen, as it's needed for the [wordle game](https://www.nytimes.com/games/wordle/index.html).

## Bonus: Wordle Cheater
You can visit https://bit.ly/sql-games to see a ClickHouse SQL code hosted on [clickhouse fiddle](https://fiddle.clickhouse.com/229101f4-a8f0-45cc-be7f-33e916805954).
Using the SQL code and combining with the response from actual game, a user can see possible solutions for Wordle.
