// Input of POST /score (TODO 2.24): titles and artists only, short fields, at most 50 songs.

export interface Song {
  title: string;
  artists: string[];
}

export const MAX_BODY_BYTES = 64 * 1024;
const MAX_SONGS = 50;
const MAX_TITLE = 200;
const MAX_ARTISTS = 10;
const MAX_ARTIST = 100;

/** The body as text, or null as soon as it exceeds `max` bytes (with or without Content-Length). */
export async function readBody(request: Request, max = MAX_BODY_BYTES): Promise<string | null> {
  if (!request.body) return "";
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > max) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

/** The songs of a /score body, or null if the body is not exactly {"songs":[{title, artists}]}. */
export function parseSongs(body: string): Song[] | null {
  if (body.length > MAX_BODY_BYTES) return null;
  let data: unknown;
  try {
    data = JSON.parse(body);
  } catch {
    return null;
  }
  if (!isObjectWithKeys(data, ["songs"])) return null;
  const songs = data.songs;
  if (!Array.isArray(songs) || songs.length < 1 || songs.length > MAX_SONGS) return null;
  return songs.every(isSong) ? (songs as Song[]) : null;
}

function isSong(value: unknown): boolean {
  if (!isObjectWithKeys(value, ["title", "artists"])) return false;
  const { title, artists } = value;
  return (
    isShortText(title, MAX_TITLE) &&
    Array.isArray(artists) &&
    artists.length >= 1 &&
    artists.length <= MAX_ARTISTS &&
    artists.every((artist) => isShortText(artist, MAX_ARTIST))
  );
}

function isShortText(value: unknown, max: number): boolean {
  return typeof value === "string" && value.trim().length > 0 && value.length <= max;
}

function isObjectWithKeys(value: unknown, keys: string[]): value is Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return false;
  const actual = Object.keys(value).sort();
  return actual.length === keys.length && [...keys].sort().every((key, i) => key === actual[i]);
}
