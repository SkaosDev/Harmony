import { describe, expect, it } from "vitest";
import cases from "../../ml/fixtures/score_cases.json";
import promptFile from "../../ml/prompts/score.txt?raw";
import { parseScores, prompt, userMessage } from "../src/prompt";

describe("shared cases with ml/llm_check.py", () => {
  it.each(cases.messages)("user message: $name", ({ songs, expected }) => {
    expect(userMessage(songs)).toBe(expected);
  });

  it.each(cases.parses)("parse: $name", ({ text, count, expected }) => {
    expect(parseScores(text, count)).toEqual(expected);
  });
});

it("bundles ml/prompts/score.txt unchanged", () => {
  expect(prompt).toBe(promptFile);
});
