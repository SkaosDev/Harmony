# Harmony Worker

The only cloud part of Harmony (`docs/PROJECT.md` §7.1): a Cloudflare Worker that holds the LLM
API key, checks the Spotify user and scores song titles. It never receives health data.

Needs Node 18+. From this folder:

| Command | What it does |
|---|---|
| `npm install` | install the tools (Wrangler, Vitest) |
| `npm run dev` | run the Worker locally on http://localhost:8787 |
| `npm test` | run the tests in the Workers runtime |
| `npm run check` | type-check (run `npm run types` after changing `wrangler.jsonc`) |

`GET /health` answers `{"ok":true}`. `POST /score` scores up to 50 songs (titles and artists
only) with Claude Haiku 5.5; the full contract (auth, limits, error codes) is in
`docs/PROJECT.md` §7.1. The prompt is `ml/prompts/score.txt`, shared with `ml/llm_check.py`.

## Secrets

Two secrets, never in Git: `ANTHROPIC_API_KEY` and `ALLOWED_SPOTIFY_IDS` (comma-separated
Spotify user IDs, the `id` of `GET /v1/me`). Locally, copy `.dev.vars.example` to `.dev.vars`
(ignored by Git) and fill it in.

## Deploy

Wrangler must be logged in once (`npx wrangler login`). The KV namespace of the daily counter
(`LIMITS`) is already created; its ID is in `wrangler.jsonc`.

| When | Command |
|---|---|
| first deploy (sends the secrets of `.dev.vars`) | `npx wrangler deploy --secrets-file .dev.vars` |
| later deploys (secrets kept) | `npx wrangler deploy` |
| change the secrets, e.g. a new pilot user | `npx wrangler secret bulk .dev.vars` |

The app reads the Worker URL from `WORKER_URL` in `app/Harmony/Config.xcconfig` (ignored by Git).
