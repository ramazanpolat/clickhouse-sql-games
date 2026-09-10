-- Renders the transcript of the current "guess the number" game. Polled by watch.sh; also fine to run by hand.
WITH (SELECT max(game_id) FROM guess_number.state) AS current_game
SELECT line
FROM
(
    SELECT 0 AS ord, format('GUESS THE NUMBER  --  game #{0}', toString(current_game)) AS line
    UNION ALL
    SELECT 1, ''
    UNION ALL
    SELECT try * 2 + 1, format('  > {0}', said)
    FROM guess_number.history
    WHERE game_id = current_game AND try > 0
    UNION ALL
    SELECT try * 2 + 2, format('  {0}', message)
    FROM guess_number.history
    WHERE game_id = current_game
    UNION ALL
    SELECT 100000, ''
    UNION ALL
    SELECT 100001, if((SELECT any(done OR lo > hi) FROM guess_number.state),
        'Play again:   INSERT INTO guess_number.input VALUES (''new game'');',
        'Your move:    INSERT INTO guess_number.input VALUES (''up'');   -- or ''down'' / ''yes''')
)
ORDER BY ord
FORMAT TSVRaw
