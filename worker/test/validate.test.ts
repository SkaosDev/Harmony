import { describe, expect, it } from "vitest";
import { parseSongs, readBody } from "../src/validate";
import { call, scoreRequest, songs } from "./helpers";

const body = (value: unknown) => JSON.stringify(value);

describe("parseSongs", () => {
  it("accepts 1 to 50 songs", () => {
    expect(parseSongs(body({ songs: songs(1) }))).toHaveLength(1);
    expect(parseSongs(body({ songs: songs(50) }))).toHaveLength(50);
  });

  it.each([
    ["not JSON", "{songs:"],
    ["not an object", body([1])],
    ["no songs", body({})],
    ["extra top-level field", body({ songs: songs(1), user: "x" })],
    ["empty list", body({ songs: [] })],
    ["51 songs", body({ songs: songs(51) })],
    ["songs not a list", body({ songs: "a" })],
    ["empty title", body({ songs: [{ title: "  ", artists: ["A"] }] })],
    ["title too long", body({ songs: [{ title: "t".repeat(201), artists: ["A"] }] })],
    ["title not a string", body({ songs: [{ title: 3, artists: ["A"] }] })],
    ["no artist", body({ songs: [{ title: "T", artists: [] }] })],
    ["11 artists", body({ songs: [{ title: "T", artists: Array(11).fill("A") }] })],
    ["artist too long", body({ songs: [{ title: "T", artists: ["a".repeat(101)] }] })],
    ["artists a string", body({ songs: [{ title: "T", artists: "A" }] })],
    ["extra song field", body({ songs: [{ title: "T", artists: ["A"], id: "x" }] })],
    ["body too large", body({ songs: songs(1), pad: "x".repeat(70_000) })],
  ])("rejects %s", (_, text) => {
    expect(parseSongs(text)).toBeNull();
  });
});

describe("POST /score input", () => {
  it("returns 400 for an invalid body", async () => {
    const response = await call(scoreRequest({ songs: songs(51) }));
    expect(response.status).toBe(400);
  });

  it("returns 400 when the body is too large", async () => {
    expect((await call(scoreRequest("x".repeat(70_000)))).status).toBe(400);
  });

  it("stops reading a streamed body without Content-Length past 64 KB", async () => {
    let sent = 0;
    const stream = new ReadableStream<Uint8Array>({
      pull(controller) {
        sent += 16_384;
        controller.enqueue(new Uint8Array(16_384));
        if (sent > 1_000_000) controller.close();
      },
    });
    const request = new Request("https://worker.test/score", { method: "POST", body: stream });
    expect(await readBody(request)).toBeNull();
    expect(sent).toBeLessThan(200_000);
  });

  it("returns 405 for GET", async () => {
    expect((await call(new Request("https://worker.test/score"))).status).toBe(405);
  });
});
