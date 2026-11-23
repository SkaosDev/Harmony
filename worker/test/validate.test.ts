import { describe, expect, it } from "vitest";
import { parseSongs } from "../src/validate";
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

  it("returns 400 when Content-Length is too large", async () => {
    const request = scoreRequest("x".repeat(70_000));
    expect((await call(request)).status).toBe(400);
  });

  it("returns 405 for GET", async () => {
    expect((await call(new Request("https://worker.test/score"))).status).toBe(405);
  });
});
