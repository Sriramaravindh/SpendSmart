# SpendSmart Gemini Proxy (Cloudflare Worker)

A tiny Cloudflare Worker that forwards Gemini `generateContent` requests to
Google, injecting the API key server-side. The Gemini API key lives **only** as
a Worker secret — it is never shipped in the Flutter app or its web build.

The Flutter app POSTs to `POST /generate` with:

```json
{ "model": "gemini-flash-latest", "contents": [ ...Gemini contents array... ] }
```

and the Worker returns Google's JSON response passthrough.

## Deploy

Run these from inside the `cloudflare-proxy/` directory:

```bash
npm install
npx wrangler login
npx wrangler secret put GEMINI_API_KEY
# ^ paste your Gemini API key when prompted. NEVER commit it to the repo.
npx wrangler deploy
```

`wrangler deploy` prints a URL like:

```
https://spendsmart-gemini-proxy.<your-subdomain>.workers.dev
```

Copy that URL — the Flutter app needs it.

## Point the Flutter app at the proxy

The app reads the proxy URL from a compile-time define (`GEMINI_PROXY_URL`).
Pass your Worker URL (no trailing slash, no `/generate` suffix — the app appends
`/generate` itself):

```bash
# Web release build:
flutter build web --dart-define=GEMINI_PROXY_URL=https://spendsmart-gemini-proxy.<your-subdomain>.workers.dev

# Local run:
flutter run --dart-define=GEMINI_PROXY_URL=https://spendsmart-gemini-proxy.<your-subdomain>.workers.dev
```

The app no longer needs `GEMINI_API_KEY` at all. If `GEMINI_PROXY_URL` is empty,
the assistant reports that it is not configured.

## Daily usage cap

The Worker enforces a daily request cap (`MAX_REQUESTS_PER_DAY`, default
`2000`) for basic abuse protection. Over the cap it returns HTTP `429` with
`{"error":"daily limit reached"}`.

**This is a soft cap.** Cloudflare runs your Worker across many edge isolates,
each holding its own in-memory counter, so the real limit is roughly
`MAX_REQUESTS_PER_DAY` times the number of active isolates.

- **Raise it:** change `MAX_REQUESTS_PER_DAY` in `src/index.js` and redeploy.
- **Make it a hard cap:** use a shared store. Create a KV namespace, bind it as
  `RATE_KV`, and use the commented KV example:

  ```bash
  npx wrangler kv namespace create RATE_KV
  ```

  Paste the returned id into the `[[kv_namespaces]]` block in `wrangler.toml`
  (uncomment it), then uncomment the `env.RATE_KV` block in `src/index.js` and
  redeploy. For strict concurrency guarantees, use Durable Objects instead.
