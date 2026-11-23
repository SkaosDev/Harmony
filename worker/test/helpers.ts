import { createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import { env } from "cloudflare:workers";
import worker from "../src";

const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;

/** Calls the Worker's fetch handler as the runtime would. */
export async function call(request: Request): Promise<Response> {
  const ctx = createExecutionContext();
  const response = await worker.fetch(new IncomingRequest(request), env, ctx);
  await waitOnExecutionContext(ctx);
  return response;
}

export function songs(count: number): { title: string; artists: string[] }[] {
  return Array.from({ length: count }, (_, i) => ({ title: `Song ${i}`, artists: [`Artist ${i}`] }));
}

export function scoreRequest(body: unknown, token: string | null = "token"): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (token) headers.authorization = `Bearer ${token}`;
  return new Request("https://worker.test/score", {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}
