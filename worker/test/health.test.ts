import { createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { expect, it } from "vitest";
import worker from "../src";

const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;

async function call(request: Request): Promise<Response> {
  const ctx = createExecutionContext();
  const response = await worker.fetch(new IncomingRequest(request), env, ctx);
  await waitOnExecutionContext(ctx);
  return response;
}

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
