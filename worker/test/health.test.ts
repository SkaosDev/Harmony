import { expect, it } from "vitest";
import { call } from "./helpers";

it("answers /health", async () => {
  const response = await call(new Request("https://worker.test/health"));
  expect(response.status).toBe(200);
  expect(await response.json()).toEqual({ ok: true });
});

it("returns 404 for an unknown route", async () => {
  expect((await call(new Request("https://worker.test/nope"))).status).toBe(404);
});

it("returns 405 for a wrong method", async () => {
  expect((await call(new Request("https://worker.test/health", { method: "POST" }))).status).toBe(405);
});
