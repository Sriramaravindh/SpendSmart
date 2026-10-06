// SpendSmart Gemini proxy (Cloudflare Worker).
//
// Keeps the Gemini API key server-side: it lives ONLY as the Worker secret
// `GEMINI_API_KEY` (set via `wrangler secret put GEMINI_API_KEY`) and is never
// shipped in the Flutter app or build. The Flutter client POSTs to /generate
// with { model, contents } and this Worker forwards to Google with the key.

// Soft daily request cap for basic abuse protection.
const MAX_REQUESTS_PER_DAY = 2000;

// In-memory counter keyed by UTC date (YYYY-MM-DD).
// NOTE: Cloudflare Workers are NOT single-instance — many isolates run across
// the edge, each with its own copy of this counter. So this is a SOFT cap
// (effective limit is roughly MAX_REQUESTS_PER_DAY * number_of_isolates).
// For a HARD, globally-accurate cap use Cloudflare KV or Durable Objects.
// See the commented env.RATE_KV example in handleGenerate() below.
let usageDate = '';
let usageCount = 0;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*', // public access (user's explicit choice)
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function jsonResponse(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function utcDateKey() {
  // e.g. "2024-09-01" — avoids any locale/timezone ambiguity.
  return new Date().toISOString().slice(0, 10);
}

// Soft in-memory cap. Returns true if the request is allowed.
function underSoftCap() {
  const today = utcDateKey();
  if (today !== usageDate) {
    usageDate = today;
    usageCount = 0;
  }
  if (usageCount >= MAX_REQUESTS_PER_DAY) return false;
  usageCount++;
  return true;
}

async function handleGenerate(request, env) {
  if (!env.GEMINI_API_KEY) {
    return jsonResponse({ error: 'server not configured' }, 500);
  }

  // Soft in-memory daily cap.
  if (!underSoftCap()) {
    return jsonResponse({ error: 'daily limit reached' }, 429);
  }

  // ---------------------------------------------------------------------------
  // HARD daily cap example using Cloudflare KV (optional).
  // Bind a KV namespace named RATE_KV in wrangler.toml, then uncomment:
  //
  // const kvKey = `count:${utcDateKey()}`;
  // const current = parseInt((await env.RATE_KV.get(kvKey)) || '0', 10);
  // if (current >= MAX_REQUESTS_PER_DAY) {
  //   return jsonResponse({ error: 'daily limit reached' }, 429);
  // }
  // // ~48h TTL so yesterday's key self-expires.
  // await env.RATE_KV.put(kvKey, String(current + 1), { expirationTtl: 172800 });
  // ---------------------------------------------------------------------------

  let body;
  try {
    body = await request.json();
  } catch (_) {
    return jsonResponse({ error: 'invalid JSON body' }, 400);
  }

  const model = body && body.model;
  const contents = body && body.contents;
  if (!model || !contents) {
    return jsonResponse({ error: 'missing "model" or "contents"' }, 400);
  }

  const url =
    'https://generativelanguage.googleapis.com/v1beta/models/' +
    encodeURIComponent(model) +
    ':generateContent?key=' +
    encodeURIComponent(env.GEMINI_API_KEY);

  const upstream = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ contents }),
  });

  // Passthrough: same status + body as Gemini, with CORS added.
  const text = await upstream.text();
  return new Response(text, {
    status: upstream.status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

export default {
  async fetch(request, env) {
    try {
      // CORS preflight.
      if (request.method === 'OPTIONS') {
        return new Response(null, { status: 204, headers: CORS_HEADERS });
      }

      const { pathname } = new URL(request.url);

      if (request.method === 'POST' && pathname === '/generate') {
        return await handleGenerate(request, env);
      }

      return jsonResponse({ error: 'not found' }, 404);
    } catch (err) {
      // Never log or echo the API key; only a generic error message.
      return jsonResponse({ error: 'internal error' }, 500);
    }
  },
};
