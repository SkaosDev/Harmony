export default {
  async fetch(request, _env, _ctx): Promise<Response> {
    const { pathname } = new URL(request.url);
    if (pathname === "/health") {
      if (request.method !== "GET") return json({ error: "method not allowed" }, 405);
      return json({ ok: true });
    }
    return json({ error: "not found" }, 404);
  },
} satisfies ExportedHandler<Env>;

function json(body: unknown, status = 200, headers: HeadersInit = {}): Response {
  return Response.json(body, { status, headers });
}
