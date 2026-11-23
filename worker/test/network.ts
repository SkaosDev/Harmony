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
