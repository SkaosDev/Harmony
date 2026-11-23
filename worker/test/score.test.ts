import { describe, expect, it } from "vitest";
import { config, prompt, userMessage } from "../src/prompt";
import { call, scoreRequest, songs } from "./helpers";
import { anthropicAnswer, network, spotifyMe } from "./network";

const answer = (count: number) =>
  JSON.stringify({ s: Array.from({ length: count }, (_, i) => ({ i, e: i % 101, p: 100 - (i % 101) })) });

describe("POST /score with the LLM", () => {
  it("returns 50 score pairs between 0 and 1 for 50 songs", async () => {
    network.use(spotifyMe("alice"), anthropicAnswer(answer(50)));
    const response = await call(scoreRequest({ songs: songs(50) }));
    expect(response.status).toBe(200);
    const { scores } = await response.json<{ scores: { energy: number; positivity: number }[] }>();
    expect(scores).toHaveLength(50);
    for (const pair of scores) {
      expect(pair.energy).toBeGreaterThanOrEqual(0);
      expect(pair.energy).toBeLessThanOrEqual(1);
      expect(pair.positivity).toBeGreaterThanOrEqual(0);
      expect(pair.positivity).toBeLessThanOrEqual(1);
    }
  });

  it("sends only the shared prompt, the titles and artists, with the secret key", async () => {
    const seen: { body: unknown; key: string | null }[] = [];
    network.use(spotifyMe("alice"), anthropicAnswer(answer(2), { seen }));
    await call(scoreRequest({ songs: songs(2) }));
    expect(seen).toHaveLength(1);
    expect(seen[0].key).toBe("Bearer test-key");
    expect(seen[0].body).toEqual({
      model: config.model,
      max_tokens: config.max_tokens,
      system: [{ type: "text", text: prompt, cache_control: { type: "ephemeral" } }],
      messages: [{ role: "user", content: userMessage(songs(2)) }],
      output_config: { effort: "low", format: { type: "json_schema", schema: config.output_schema } },
    });
  });

  it("returns null for songs the LLM did not score", async () => {
    network.use(spotifyMe("alice"), anthropicAnswer('{"s":[{"i":0,"e":20,"p":30},{"i":2,"e":101,"p":5}]}'));
    const response = await call(scoreRequest({ songs: songs(3) }));
    expect(await response.json()).toEqual({ scores: [{ energy: 0.2, positivity: 0.3 }, null, null] });
  });

  it("returns 502 when the API fails", async () => {
    network.use(spotifyMe("alice"), anthropicAnswer("", { status: 400 }));
    expect((await call(scoreRequest({ songs: songs(1) }))).status).toBe(502);
  });

  it("returns 502 when the answer is cut", async () => {
    network.use(spotifyMe("alice"), anthropicAnswer('{"s":[{"i":0,', { stopReason: "max_tokens" }));
    expect((await call(scoreRequest({ songs: songs(1) }))).status).toBe(502);
  });
});
