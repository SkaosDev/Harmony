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

/** Energy and positivity in 0..1 per song, or null when the answer has no single valid triple. */
export function parseScores(text: string, count: number): (Score | null)[] {
  let triples: unknown;
  try {
    triples = (JSON.parse(text) as { s?: unknown })?.s;
  } catch {
    return Array(count).fill(null);
  }
  if (!Array.isArray(triples)) return Array(count).fill(null);
  const found = new Map<number, unknown[][]>();
  for (const triple of triples) {
    if (Array.isArray(triple) && Number.isInteger(triple[0]) && triple[0] >= 0 && triple[0] < count) {
      found.set(triple[0], [...(found.get(triple[0]) ?? []), triple]);
    }
  }
  return Array.from({ length: count }, (_, i) => {
    const matches = found.get(i) ?? [];
    const [, energy, positivity] = matches[0] ?? [];
    return matches.length === 1 && matches[0].length === 3 && isScore(energy) && isScore(positivity)
      ? { energy: energy / 100, positivity: positivity / 100 }
      : null;
  });
}
