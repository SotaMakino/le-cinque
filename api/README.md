# API

Go backend for Le Cinque. In production it runs on Cloud Run
(`asia-southeast1`, alongside the Neon Postgres it queries); the frontend
reaches it same-origin through the Cloudflare Pages `/api/*` proxy.

Deploying is one command from the repo root:

```
gcloud run deploy le-cinque-api \
  --source api \
  --region asia-southeast1 \
  --service-account lecinque@moonlit-text-503205-c7.iam.gserviceaccount.com \
  --set-secrets DATABASE_URL=DATABASE_URL:latest \
  --set-env-vars ALLOWED_ORIGIN=https://le-cinque.pages.dev \
  --allow-unauthenticated \
  --max-instances 3 \
  --cpu-boost
```

`--max-instances` is a cost ceiling, not a capacity estimate: it is what keeps
a traffic spike inside the free tier instead of inside the bill.

## Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | `8080` | Port to listen on. Cloud Run injects this. |
| `DATABASE_URL` | `postgres://localhost:5432/hellodb` | Postgres connection string. |
| `ALLOWED_ORIGIN` | `http://localhost:5173` | Comma-separated CORS origins. |
| `GOOGLE_TTS_CREDENTIALS` | _(unset)_ | Service-account key JSON for word pronunciation (see below). Not needed on Cloud Run, which authenticates as its own service account. |

## Word pronunciation (Google Cloud TTS)

The 🔊 button pronounces Italian words. Chromium browsers use their own good
built-in voice; Firefox and Safari only expose a low-quality voice, so for those
the frontend fetches natural audio from `GET /tts`, which calls Google Cloud
Text-to-Speech. Synthesised MP3s are cached in memory (the vocabulary is small
and fixed), keeping usage well inside the free tier.

In production this needs no configuration: Cloud Run runs the service as a
service account, and the credentials are read from the metadata server via
Application Default Credentials. Enabling the **Cloud Text-to-Speech API** on
the project and deploying with `--service-account` is the whole setup.

Elsewhere — another host, or local development — set
`GOOGLE_TTS_CREDENTIALS` to the full contents of a service-account JSON key.
Locally, `gcloud auth application-default login` works too, since ADC picks
those credentials up as well.

Without either, `/tts` returns `503` and the app falls back to browser speech,
so the game still works — Firefox/Safari just get the lower-quality voice.
