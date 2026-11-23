import { isAllowed, spotifyUserId } from "./spotify";
import { parseSongs, readBody } from "./validate";

export default {
  async fetch(request, env, _ctx): Promise<Response> {
    const { pathname } = new URL(request.url);
    if (pathname === "/health") {
      if (request.method !== "GET") return json({ error: "method not allowed" }, 405);
      return json({ ok: true });
    }
    if (pathname === "/score") {
      if (request.method !== "POST") return json({ error: "method not allowed" }, 405);
      return score(request, env);
    }
    return json({ error: "not found" }, 404);
  },
} satisfies ExportedHandler<Env>;

async function score(request: Request, env: Env): Promise<Response> {
  const token = /^Bearer (\S+)$/.exec(request.headers.get("authorization") ?? "")?.[1];
  if (!token) return json({ error: "missing Spotify token" }, 401);
  const body = await readBody(request);
  const songs = body === null ? null : parseSongs(body);
  if (!songs) return json({ error: "invalid input" }, 400);

  let userId: string | null;
  try {
    userId = await spotifyUserId(token);
  } catch (error) {
    console.error(JSON.stringify({ message: "spotify check failed", error: String(error) }));
    return json({ error: "Spotify unavailable" }, 502);
  }
  if (!userId) return json({ error: "invalid Spotify token" }, 401);
  if (!isAllowed(userId, env.ALLOWED_SPOTIFY_IDS)) return json({ error: "user not allowed" }, 403);
  return json({ error: "not implemented" }, 501);
}

function json(body: unknown, status = 200, headers: HeadersInit = {}): Response {
  return Response.json(body, { status, headers });
}
