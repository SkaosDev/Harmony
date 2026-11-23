import { describe, expect, it } from "vitest";
import { isAllowed } from "../src/spotify";
import { call, scoreRequest, songs } from "./helpers";
import { anthropicAnswer, network, spotifyMe } from "./network";

describe("POST /score authentication", () => {
  it("returns 401 without a Bearer token", async () => {
    expect((await call(scoreRequest({ songs: songs(1) }, null))).status).toBe(401);
  });

  it("returns 401 when Spotify rejects the token", async () => {
    network.use(spotifyMe(401));
    expect((await call(scoreRequest({ songs: songs(1) }, "unknown"))).status).toBe(401);
  });

  it("returns 403 for a Spotify user not on the list", async () => {
    network.use(spotifyMe("mallory"));
    expect((await call(scoreRequest({ songs: songs(1) }))).status).toBe(403);
  });

  it("returns 502 when Spotify fails", async () => {
    network.use(spotifyMe(503));
    expect((await call(scoreRequest({ songs: songs(1) }))).status).toBe(502);
  });

  it("lets an allowed user through", async () => {
    network.use(spotifyMe("bob"), anthropicAnswer('{"s":[{"i":0,"e":50,"p":50}]}'));
    expect((await call(scoreRequest({ songs: songs(1) }))).status).toBe(200);
  });
});

describe("isAllowed", () => {
  it("matches whole IDs of the comma-separated list", () => {
    expect(isAllowed("bob", "alice, bob")).toBe(true);
    expect(isAllowed("bo", "alice, bob")).toBe(false);
    expect(isAllowed("", "alice,,bob")).toBe(false);
  });
});
