"""LLM song scores (TODO 2.29): shared cases with the Worker. Synthetic titles only."""

import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import llm_check as L                                            # noqa: E402

CASES = json.loads((Path(__file__).resolve().parents[1] / "fixtures" / "score_cases.json")
                   .read_text(encoding="utf-8"))


class SharedCasesTests(unittest.TestCase):
    def test_user_message(self):
        for case in CASES["messages"]:
            with self.subTest(case["name"]):
                self.assertEqual(L.user_message(case["songs"]), case["expected"])

    def test_parse_scores(self):
        for case in CASES["parses"]:
            with self.subTest(case["name"]):
                self.assertEqual(L.parse_scores(case["text"], case["count"]), case["expected"])


class RequestTests(unittest.TestCase):
    def test_request_uses_the_shared_prompt_and_schema(self):
        params = L.request_params([{"title": "T", "artists": ["A"]}])
        self.assertEqual(params["model"], "claude-haiku-4-5")
        self.assertEqual(params["system"], L.load_prompt())
        self.assertEqual(params["messages"], [{"role": "user", "content": "0\tT\tA"}])
        self.assertEqual(params["output_config"]["format"]["schema"], L.load_config()["output_schema"])
        self.assertNotIn("thinking", params)          # fewest tokens: Haiku 4.5 without thinking


if __name__ == "__main__":
    unittest.main()
