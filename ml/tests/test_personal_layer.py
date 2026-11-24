"""Synthetic golden checks for the energy-only shadow personal layer."""
import json
import sys
import unittest
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import personal_layer as P  # noqa: E402


class PersonalLayerTests(unittest.TestCase):
    def setUp(self):
        fixture = Path(__file__).resolve().parents[1] / "fixtures" / "personal_layer_cases.json"
        self.cases = json.loads(fixture.read_text())["cases"]

    @staticmethod
    def date(value):
        return datetime.fromisoformat(value.replace("Z", "+00:00"))

    def observation(self, item):
        return P.Observation(self.date(item["answered_at"]), item["energy"], item["z_energy"],
                             item["label"], item["usable"])

    def test_golden_offsets_and_probabilities(self):
        for case in self.cases[:-1]:
            offset, probability, count = P.estimate(self.date(case["now"]), case["z_energy"],
                                                     [self.observation(x) for x in case["observations"]])
            self.assertAlmostEqual(offset, case["offset"], places=12, msg=case["name"])
            self.assertAlmostEqual(probability, case["probability"], places=12, msg=case["name"])
            self.assertEqual(count, case["usable_labelled_count"], case["name"])

    def test_past_label_fixture(self):
        case = self.cases[-1]
        label = P.past_label(self.date(case["now"]), case["energy"],
                             [self.observation(x) for x in case["prior_responses"]])
        self.assertEqual(label, case["label"])


if __name__ == "__main__":
    unittest.main()
