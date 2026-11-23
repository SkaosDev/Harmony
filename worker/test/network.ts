import { setupNetwork } from "@msw/cloudflare";
import { http, HttpResponse } from "msw";

/** Outbound requests (Spotify, Anthropic) are mocked: tests never reach the real services. */
export const network = setupNetwork();

/** Spotify /v1/me answering for this user ID, or with this status. */
export function spotifyMe(answer: string | number) {
  return http.get("https://api.spotify.com/v1/me", () =>
    typeof answer === "string"
      ? HttpResponse.json({ id: answer, display_name: "x" })
      : HttpResponse.json({ error: { status: answer } }, { status: answer }),
  );
}

/** Anthropic Messages API answering this text; `seen` receives each request body and API key. */
export function anthropicAnswer(
  text: string,
  { stopReason = "end_turn", status = 200, seen = [] as { body: unknown; key: string | null }[] } = {},
) {
  return http.post("https://api.anthropic.com/v1/messages", async ({ request }) => {
    seen.push({ body: await request.json(), key: request.headers.get("authorization") });
    if (status !== 200) {
      return HttpResponse.json({ type: "error", error: { type: "invalid_request_error", message: "x" } }, { status });
    }
    return HttpResponse.json({
      id: "msg_test",
      type: "message",
      role: "assistant",
      model: "claude-haiku-5-5",
      content: [{ type: "text", text }],
      stop_reason: stopReason,
      stop_sequence: null,
      usage: { input_tokens: 1, output_tokens: 1 },
    });
  });
}
