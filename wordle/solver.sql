-- Wordle solver (the "cheater" from the ClickHouse SQL Games talk).
--
--   black    gray letters (excluded)
--   white    yellow + green letters (all must be present)
--   pattern  green letters in place, "." or "_" for unknown, e.g. "_a__e" (optional)
--
--   clickhouse local --param_black=dur --param_white=ae --param_pattern=_a__e --queries-file solver.sql
--
-- Reads the word list with file(); solve.sh passes the bundled sgb-words.txt via --param_words.
WITH
    lower({black:String}) AS blacklist,
    lower({white:String}) AS whitelist,
    if({pattern:String} = '', '.....', replaceAll(lower({pattern:String}), '_', '.')) AS pattern
SELECT
    rowNumberInAllBlocks() + 1 AS num,
    upper(word) AS word
FROM
(
    SELECT word
    FROM file({words:String}, 'LineAsString', 'word String')
    WHERE length(word) = 5
      AND NOT arrayExists(c -> position(word, c) > 0, splitByString('', blacklist))
      AND arrayAll(c -> position(word, c) > 0, splitByString('', whitelist))
      AND match(word, '^' || pattern || '$')
    ORDER BY word
);
