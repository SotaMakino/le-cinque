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

## When to run this (there is no CI for it)

Two layers keep a slowdown from sneaking in:

**Passive net — it tells you.** `middleware.Logging` prints `SLOW …` for any
request over 200ms (a threshold set above the intentionally slow bcrypt and TTS
paths). Just using the app surfaces a regression in the server log — no run, no
memory needed. When you see `SLOW`, come here and measure.

**Deliberate run — when you touch the data path.** Run `k6 run loadtest/play.ts`
(or just `EXPLAIN` on the one query) when a change could affect query cost:

- add or change a SQL query (new `WHERE` / `JOIN` / `ORDER BY`, or a query in a loop)
- add an endpoint that reads or writes the DB
- add a table or column, or touch an index
- change a hot handler (`Current`, `Guess`, `Me`)
- before a deploy, as a manual gate
- bump Go, pgx, or Postgres versions

Frontend, CSS, copy, or word-list edits don't touch query cost — no need.

Quick vs. full: for **one** new query, `EXPLAIN (ANALYZE)` (seconds) beats a full
`k6` run (~40s) and shows `Seq Scan` vs `Index Scan` immediately.

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

## Cold-start measurement (Render vs Cloud Run)

The k6 kit above measures the **warm** DB hot path. Cold start is a different,
deploy-level metric: how long the first request takes after the service has been
idle long enough to spin down (Render free: ~15 min; Cloud Run without
`min-instances`: ~15 min). A load test can't see it — request #1 warms the
server and every request after is warm. So this uses a single `curl`.

`coldstart.sh` hits an **unregistered** path (`/_coldping`) on purpose: it
returns 404 from the booted server, so the timing is pure boot + network — no
DB, no auth. The number that matters is **`TTFB`** (time-to-first-byte); on a
cold start the whole container boot happens before the first byte.

```sh
# COLD — the headline metric. Leave the service idle >15 min first, then:
./loadtest/coldstart.sh https://your-app.onrender.com
# repeat 3–5 times (15+ min apart) for a range, not one lucky sample

# WARM — baseline, proves the network path itself is fine:
./loadtest/coldstart.sh https://your-app.onrender.com warm
```

Every run is appended to `coldstart-results.csv` (one row per request, tagged
with timestamp, host, and mode), so before (Render) and after (Cloud Run)
numbers pile up in one file. Compare with e.g.:

```sh
column -s, -t loadtest/coldstart-results.csv   # quick read
```

Run the exact same two commands against the Cloud Run URL after migrating, from
the **same machine and network** (so network latency is a constant), and compare
cold TTFB to cold TTFB.

| | Render free (cold) | Cloud Run, scale-to-zero (cold) | Cloud Run, `min-instances=1` |
|---|---|---|---|
| TTFB | tens of seconds → minutes | ~1–3 s | warm always (~50–200 ms) |

Warm latency barely changes between platforms — the migration's whole value is
in the **cold** column. That's the before/after story worth capturing.

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
- `coldstart.sh` — measure cold-start vs warm TTFB of a deployed server (Render vs Cloud Run).
- `coldstart-results.csv` — created on first run; accumulates every measurement.
