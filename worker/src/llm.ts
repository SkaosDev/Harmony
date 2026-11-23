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
    // Cached prefix (the prompt is over the 512-token minimum of Haiku 5.5): cheaper when a
    // library is scored in several requests in a row.
    system: [{ type: "text", text: prompt, cache_control: { type: "ephemeral" } }],
    messages: [{ role: "user", content: userMessage(songs) }],
    output_config: {
      effort: config.effort as Anthropic.OutputConfig["effort"],
      format: { type: "json_schema", schema: config.output_schema },
    },
  });
  if (message.stop_reason !== "end_turn") throw new Error(`LLM stop_reason ${message.stop_reason}`);
  const text = message.content.find((block) => block.type === "text")?.text ?? "";
  return parseScores(text, songs.length);
}
