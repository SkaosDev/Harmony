import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, it } from "vitest";
import { DAILY_LIMIT, overDailyLimit } from "../src/limit";
import { call, scoreRequest, songs } from "./helpers";
import { anthropicAnswer, network, spotifyMe } from "./network";

const today = () => `count:alice:${new Date().toISOString().slice(0, 10)}`;

describe("daily limit per user", () => {
  beforeEach(async () => {
    await env.LIMITS.delete(today());
  });

  it("returns 429 with Retry-After on request 51 of the day", async () => {
    network.use(spotifyMe("alice"), anthropicAnswer('{"s":[[0,50,50]]}'));
    for (let i = 0; i < DAILY_LIMIT; i++) {
      expect((await call(scoreRequest({ songs: songs(1) }))).status).toBe(200);
    }
    const response = await call(scoreRequest({ songs: songs(1) }));
    expect(response.status).toBe(429);
    const retryAfter = Number(response.headers.get("retry-after"));
    expect(retryAfter).toBeGreaterThan(0);
    expect(retryAfter).toBeLessThanOrEqual(24 * 3600);
  });

  it("does not limit another user", async () => {
    await env.LIMITS.put(today(), String(DAILY_LIMIT));
    network.use(spotifyMe("bob"), anthropicAnswer('{"s":[[0,50,50]]}'));
    expect((await call(scoreRequest({ songs: songs(1) }))).status).toBe(200);
  });

  it("does not count refused requests (400, 401, 403)", async () => {
    network.use(spotifyMe("alice"));
    await call(scoreRequest({ songs: [] }));
    await call(scoreRequest({ songs: songs(1) }, null));
    network.use(spotifyMe("mallory"));
    await call(scoreRequest({ songs: songs(1) }));
    expect(await env.LIMITS.get(today())).toBeNull();
  });

  it("resets at 00:00 UTC", async () => {
    const lateEvening = new Date("2026-11-23T23:59:00Z");
    for (let i = 0; i < DAILY_LIMIT; i++) await overDailyLimit(env.LIMITS, "carol", lateEvening);
    expect(await overDailyLimit(env.LIMITS, "carol", lateEvening)).toBe(60);
    expect(await overDailyLimit(env.LIMITS, "carol", new Date("2026-11-24T00:00:01Z"))).toBeNull();
  });
});
