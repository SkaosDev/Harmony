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
        self.fixture = json.loads(fixture.read_text())
        self.cases = self.fixture["cases"]

    def test_header_gives_the_parameters_used(self):
        self.assertEqual((self.fixture["decay_days"], self.fixture["prior_std"],
                          self.fixture["minimum_past_responses"], self.fixture["newton_steps"]),
                         (P.DECAY_DAYS, P.ENERGY_PRIOR_STD, P.MIN_LABEL_RESPONSES, P.NEWTON_STEPS))

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
