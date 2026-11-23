// Song scores from the LLM (TODO 2.26). The key comes from the ANTHROPIC_API_KEY secret only.
import Anthropic from "@anthropic-ai/sdk";
import { config, parseScores, prompt, type Score, userMessage } from "./prompt";
import type { Song } from "./validate";

/** One score pair (or null) per song, in order. Throws if the API fails or the answer is cut. */
export async function scoreSongs(songs: Song[], apiKey: string): Promise<(Score | null)[]> {
  const client = new Anthropic({ apiKey });
  const message = await client.messages.create({
    model: config.model,
    max_tokens: config.max_tokens,
    system: prompt,
    messages: [{ role: "user", content: userMessage(songs) }],
    output_config: { format: { type: "json_schema", schema: config.output_schema } },
  });
  if (message.stop_reason !== "end_turn") throw new Error(`LLM stop_reason ${message.stop_reason}`);
  const text = message.content.find((block) => block.type === "text")?.text ?? "";
  return parseScores(text, songs.length);
}
