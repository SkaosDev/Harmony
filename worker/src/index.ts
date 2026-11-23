import { MAX_BODY_BYTES, parseSongs } from "./validate";

export default {
  async fetch(request, _env, _ctx): Promise<Response> {
    const { pathname } = new URL(request.url);
    if (pathname === "/health") {
      if (request.method !== "GET") return json({ error: "method not allowed" }, 405);
      return json({ ok: true });
    }
    if (pathname === "/score") {
      if (request.method !== "POST") return json({ error: "method not allowed" }, 405);
      return score(request);
    }
    return json({ error: "not found" }, 404);
  },
} satisfies ExportedHandler<Env>;

async function score(request: Request): Promise<Response> {
  if (Number(request.headers.get("content-length") ?? 0) > MAX_BODY_BYTES) {
    return json({ error: "invalid input" }, 400);
  }
  const songs = parseSongs(await request.text());
  if (!songs) return json({ error: "invalid input" }, 400);
  return json({ error: "not implemented" }, 501);
}

function json(body: unknown, status = 200, headers: HeadersInit = {}): Response {
  return Response.json(body, { status, headers });
}
