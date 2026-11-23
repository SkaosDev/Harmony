// Requests per user and per UTC day (TODO 2.27). KV is eventually consistent: the count can be
// slightly over under concurrent requests, which is fine for a handful of users.

export const DAILY_LIMIT = 50;
const TWO_DAYS = 2 * 24 * 3600;

/** Counts one request for this user today. Returns the seconds until 00:00 UTC if the limit is
 *  already reached (nothing counted), else null. */
export async function overDailyLimit(kv: KVNamespace, userId: string, now = new Date()): Promise<number | null> {
  const key = `count:${userId}:${now.toISOString().slice(0, 10)}`;
  const count = Number(await kv.get(key)) || 0;
  if (count >= DAILY_LIMIT) {
    const midnight = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1);
    return Math.ceil((midnight - now.getTime()) / 1000);
  }
  await kv.put(key, String(count + 1), { expirationTtl: TWO_DAYS });
  return null;
}
