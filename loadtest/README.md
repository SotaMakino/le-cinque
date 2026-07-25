# Load-test kit — measure before optimizing

A free, all-local way to measure whether the missing database indexes actually
matter, so any later change is backed by numbers instead of a guess.

- **k6** drives HTTP traffic and reports API latency (the *where*).
- **`EXPLAIN ANALYZE`** on the local database shows *why* a query is slow —
  specifically `Seq Scan` (reads the whole table) vs `Index Scan`.

Nothing here changes the app. All files use usernames prefixed `loadtest_`, and
`cleanup.sql` removes exactly what the kit created.

`DB` below is your local database:
`postgres://localhost:5432/hellodb?sslmode=disable`

---

## One-time setup

```sh
mise install             # provisions k6 (pinned in mise.toml), the free load generator
# Postgres + the Go server are already running locally.
```

---

## The measurement loop

### 1. Seed realistic data
An empty table is fast no matter what, so fill it first (~10k games, ~120k guesses):

```sh
psql "postgres://localhost:5432/hellodb?sslmode=disable" -f loadtest/seed.sql
```

### 2. Look at the SQL side (the proof)
Run the two hot-path queries with `EXPLAIN (ANALYZE, BUFFERS)`. Today you should
see **`Seq Scan`** in both:

```sh
# latest(): newest game for a player
psql "$DB" -c "EXPLAIN (ANALYZE, BUFFERS)
  SELECT id, word, status, direction FROM games
  WHERE username = 'loadtest_1' ORDER BY id DESC LIMIT 1;"

# attempts(): all guesses for a game
psql "$DB" -c "EXPLAIN (ANALYZE, BUFFERS)
  SELECT guess FROM guesses
  WHERE game_id = (SELECT id FROM games WHERE username LIKE 'loadtest_%' LIMIT 1)
  ORDER BY id;"
```

Note the `Execution Time` and whether it says `Seq Scan` or `Index Scan`.

### 3. Measure the API side (the baseline)
```sh
k6 run loadtest/play.ts
```
In the summary, find the **`GET /game`** line under `http_req_duration` and
write down its **p95**. That is your baseline number.

### 4. (Later) add the indexes, then repeat 2–3 and compare
When you decide to apply the fix:
```sql
CREATE INDEX IF NOT EXISTS idx_games_username_id ON games (username, id DESC);
CREATE INDEX IF NOT EXISTS idx_guesses_game_id   ON guesses (game_id);
ANALYZE games; ANALYZE guesses;
```
Re-run step 2 (should now say `Index Scan`) and step 3 (p95 should drop). Now the
improvement is a measured fact.

### 5. Clean up
```sh
psql "postgres://localhost:5432/hellodb?sslmode=disable" -f loadtest/cleanup.sql
```

---

## Optional: `pg_stat_statements` (aggregate view of every query)

`EXPLAIN` inspects one query you name. `pg_stat_statements` records *all* of
them and ranks them by total time — handy for finding offenders you didn't
suspect. It needs a one-time server config (a restart), which is why the loop
above uses `EXPLAIN` instead. If you want it:

1. Add to `postgresql.conf` (Homebrew: `/opt/homebrew/var/postgresql@16/postgresql.conf`):
   `shared_preload_libraries = 'pg_stat_statements'`
2. Restart Postgres (`brew services restart postgresql@16`).
3. `psql "$DB" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"`
4. Reset, run the k6 test, then read the ranking:
   ```sql
   SELECT pg_stat_statements_reset();
   -- ...run k6...
   SELECT calls, round(mean_exec_time::numeric, 2) AS mean_ms,
          round(total_exec_time::numeric, 2) AS total_ms, query
   FROM pg_stat_statements
   ORDER BY total_exec_time DESC
   LIMIT 10;
   ```

## Files
- `seed.sql` — fill the local DB with load-test rows (edit the counts to taste).
- `play.ts` — k6 scenario: 20 concurrent guests hitting the game hot path.
- `cleanup.sql` — delete every `loadtest_%` row and re-analyze.
