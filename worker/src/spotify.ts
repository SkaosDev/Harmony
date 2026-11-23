// Who is calling (TODO 2.25): the app sends its Spotify access token, Spotify says whose it is.

/** Spotify user ID of the token's owner, or null if Spotify rejects the token. Throws if Spotify fails. */
export async function spotifyUserId(token: string): Promise<string | null> {
  const response = await fetch("https://api.spotify.com/v1/me", {
    headers: { authorization: `Bearer ${token}` },
  });
  if (response.status >= 400 && response.status < 500 && response.status !== 429) return null;
  if (!response.ok) throw new Error(`Spotify /v1/me answered ${response.status}`);
  const { id } = await response.json<{ id?: unknown }>();
  return typeof id === "string" && id !== "" ? id : null;
}

/** True if the ID is in the comma-separated allowlist secret. */
export function isAllowed(id: string, allowlist: string): boolean {
  return id !== "" && allowlist.split(",").some((allowed) => allowed.trim() === id);
}
