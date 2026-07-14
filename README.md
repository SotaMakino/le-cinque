# hello-go

pnpm monorepo with a Go API and a Vite + React client.

```
apps/
├── api/   # Go REST API (SQLite)
└── web/   # Vite + React client
```

## Setup

```bash
pnpm install
```

## Run the server (API)

```bash
pnpm dev:api
# or
cd apps/api && go run .
```

Runs on http://localhost:8080 (override with `PORT`; database path with `DB_PATH`).

## Run the client (web)

```bash
pnpm dev:web
# or
cd apps/web && pnpm dev
```

Runs on http://localhost:5173.

## Test

```bash
pnpm test:api
```
