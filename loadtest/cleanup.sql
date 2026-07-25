-- Remove everything seed.sql and play.js created. Matches every username the
-- kit uses: 'loadtest_<n>' from the seed and 'loadtest_vu_<n>' from k6.
--
-- Run: psql "postgres://localhost:5432/hellodb?sslmode=disable" -f loadtest/cleanup.sql

BEGIN;

DELETE FROM guesses
 WHERE game_id IN (SELECT id FROM games WHERE username LIKE 'loadtest_%');
DELETE FROM games        WHERE username LIKE 'loadtest_%';
DELETE FROM word_reviews WHERE username LIKE 'loadtest_%';
DELETE FROM study_days   WHERE username LIKE 'loadtest_%';

COMMIT;

ANALYZE games;
ANALYZE guesses;

SELECT
  (SELECT count(*) FROM games)   AS games_left,
  (SELECT count(*) FROM guesses) AS guesses_left;
