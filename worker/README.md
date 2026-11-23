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

`GET /health` answers `{"ok":true}`.
