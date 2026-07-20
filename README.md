# hello-go

Bun monorepo: **Parole**, a Wordle clone with Italian five-letter words, built as
a Go REST API plus a Vite + ReScript (React) client. Each user gets their own
games behind cookie-session auth; guesses are scored server-side so the answer
never reaches the browser until the game is over.

```
apps/
├── api/   # Go REST API (PostgreSQL, cookie-session auth)
└── web/   # Vite + ReScript (React) client
```

Live at **https://hello-go.pages.dev** (API on https://hello-go-hail.onrender.com).

## Setup

```bash
bun install
```

Requires a local PostgreSQL server. The API creates its tables on startup in the `hellodb` database:

```bash
createdb hellodb
```

## Run the server (API)

```bash
bun run dev:api
# or
cd apps/api && go run .
```

Runs on http://localhost:8080. Environment variables:

| Variable         | Default                             |
| ---------------- | ----------------------------------- |
| `PORT`           | `8080`                              |
| `DATABASE_URL`   | `postgres://localhost:5432/hellodb` |
| `ALLOWED_ORIGIN` | `http://localhost:5173` (CORS)      |

Endpoints: `POST /signup`, `POST /login`, `POST /logout` (public), and — with a
session cookie, scoped to the logged-in user:

- `GET /game` — current game state (starts one if the user has none)
- `POST /game` — new game, once the current one is won or lost
- `POST /game/guess` — submit `{"guess": "fiore"}`; the response scores each
  letter as `correct` / `present` / `absent` and reveals the answer only when
  the game ends

The answer pool and guess dictionary are the embedded Italian word list in
`apps/api/handlers/words.go`.

## Run the client (web)

```bash
bun run dev:web
# or
cd apps/web && bun run dev
```

Runs on http://localhost:5173. While editing `.res` files, keep the compiler
running in a second terminal:

```bash
cd apps/web && bun run res:watch
```

The API base URL comes from `VITE_API_URL` (see `apps/web/.env.production`),
falling back to http://localhost:8080 in dev.

## Lint & format

```bash
cd apps/web
bun run format   # rescript format -all
bun run lint     # format check + compile with warnings as errors
```

## Test

```bash
createdb hellodb_test   # once
bun run test:api
```

Tests run against the `hellodb_test` database (override with `TEST_DATABASE_URL`)
and skip if PostgreSQL is unavailable. CI runs them against a real Postgres
service container, plus the web lint and build.

## Deploy

- **Web** — Cloudflare Pages: root directory `apps/web`, build command
  `bun install && bun run build`, output `dist`.
- **API** — Render, built from `apps/api/Dockerfile` with `DATABASE_URL` and
  `ALLOWED_ORIGIN` set in the dashboard.
