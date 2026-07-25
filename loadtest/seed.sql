-- Seed the LOCAL database with enough rows that the missing-index cost becomes
-- visible. On an empty table Postgres is fast no matter what, so without this
-- step a load test tells you nothing.
--
-- Every fake row uses a username starting with 'loadtest_' so cleanup.sql can
-- delete exactly what this created and nothing else.
--
-- Run:   psql "postgres://localhost:5432/hellodb?sslmode=disable" -f loadtest/seed.sql
-- Re-run: run cleanup.sql first (this script is not idempotent).
--
-- To make the effect bigger, raise the 10000 and 12 below and re-run.

BEGIN;

-- 10,000 rounds spread over 200 fake players
INSERT INTO games (username, word, status, direction)
SELECT
  'loadtest_' || (g % 200),                     -- 200 distinct usernames
  'TRENO,ACQUA,GATTO,SOLE,UOMO',                -- a real five-word round
  (ARRAY['won', 'lost', 'playing'])[1 + (g % 3)],
  (ARRAY['it', 'en'])[1 + (g % 2)]
FROM generate_series(1, 10000) AS g;

-- ~12 guesses per seeded round (~120,000 rows), in the real "L:word:pos" format
INSERT INTO guesses (game_id, guess)
SELECT gm.id,
       (ARRAY['A','E','I','O','U','T','R','N','S','L'])[1 + (n % 10)]
         || ':' || (n % 5) || ':' || (n % 4)
FROM games gm
CROSS JOIN generate_series(1, 12) AS n
WHERE gm.username LIKE 'loadtest_%';

COMMIT;

-- refresh the planner's statistics so EXPLAIN reflects the new row counts
ANALYZE games;
ANALYZE guesses;

SELECT
  (SELECT count(*) FROM games   WHERE username LIKE 'loadtest_%') AS seeded_games,
  (SELECT count(*) FROM guesses gm
     WHERE gm.game_id IN (SELECT id FROM games WHERE username LIKE 'loadtest_%')) AS seeded_guesses;
