-- Renders the board of the current Wordle game. Polled by watch.sh; also fine to run by hand.
WITH
    (SELECT (game_id, try, target_str, input_str) FROM wordle.games) AS g,
    g.1 AS game_id,
    g.2 AS tries,
    g.3 AS target,
    g.4 AS last_guess,
    tries > 0 AND last_guess = target AS won,
    tries >= 6 AND NOT won AS lost
SELECT line
FROM
(
    SELECT 0 AS ord, format('WORDLE  --  game #{0}', toString(game_id)) AS line
    UNION ALL
    SELECT 1, ''
    UNION ALL
    SELECT try + 1, format('  {0}/6  {1}', toString(try), wordle_colored(target_str, input_str))
    FROM wordle.history
    WHERE game_id = g.1 AND try > 0
    UNION ALL
    SELECT 90, ''
    UNION ALL
    SELECT 100, multiIf(
        target = '', 'No words loaded. Run ./install.sh wordle (it fills wordle.words from sgb-words.txt).',
        won,        format('You won in {0}/6!', toString(tries)),
        lost,       format('You lost. The word was {0}.', target),
        tries = 0,  'New game. Guess a 5-letter word.',
                    format('{0} left.', toString(6 - tries)))
    UNION ALL
    SELECT 101, if(won OR lost,
        'Play again:   INSERT INTO wordle.input VALUES (''new game'');',
        'Your move:    INSERT INTO wordle.input VALUES (''crane'');')
)
ORDER BY ord
FORMAT TSVRaw
