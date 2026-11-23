// The LLM request, shared with ml/llm_check.py (TODO 2.29): same prompt file, same settings,
// same message format and same parsing rules (cases in ml/fixtures/score_cases.json).
import config from "../../ml/prompts/score_config.json";
import prompt from "../../ml/prompts/score.txt";
import type { Song } from "./validate";

export { config, prompt };

export interface Score {
  energy: number;
  positivity: number;
}

const clean = (text: string) => text.replace(/[\x00-\x1f\x7f]+/g, " ");

/** One line per song: index, title, artists (control characters become a space). */
export function userMessage(songs: Song[]): string {
  return songs
    .map((song, i) => `${i}\t${clean(song.title)}\t${song.artists.map(clean).join(", ")}`)
    .join("\n");
}

const isScore = (value: unknown): value is number =>
  Number.isInteger(value) && (value as number) >= 0 && (value as number) <= 100;

const isObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

/** Energy and positivity in 0..1 per song, or null when the answer has no single valid item. */
export function parseScores(text: string, count: number): (Score | null)[] {
  let items: unknown;
  try {
    items = (JSON.parse(text) as { s?: unknown })?.s;
  } catch {
    return Array(count).fill(null);
  }
  if (!Array.isArray(items)) return Array(count).fill(null);
  const found = new Map<number, Record<string, unknown>[]>();
  for (const item of items) {
    const i = isObject(item) ? item.i : undefined;
    if (typeof i === "number" && Number.isInteger(i) && i >= 0 && i < count) {
      found.set(i, [...(found.get(i) ?? []), item as Record<string, unknown>]);
    }
  }
  return Array.from({ length: count }, (_, i) => {
    const matches = found.get(i) ?? [];
    const item = matches[0] ?? {};
    const exactKeys = Object.keys(item).sort().join(",") === "e,i,p";
    return matches.length === 1 && exactKeys && isScore(item.e) && isScore(item.p)
      ? { energy: item.e / 100, positivity: item.p / 100 }
      : null;
  });
}
