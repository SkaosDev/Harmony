import sys
import unittest
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from uci_build_features import ITEMS, activation_score, cumulative_steps, localize
from features import label_high


class UciTests(unittest.TestCase):
    def test_cumulative_steps_reboot(self):
        np.testing.assert_array_equal(cumulative_steps([0, 4, 9, 2, 6]), [0, 4, 5, 2, 4])

    def test_la_dst_offsets_change(self):
        # UTC instants spanning the 2026 spring transition in Los Angeles.
        ts = np.array([pd.Timestamp("2026-03-08T09:30:00Z").value//10**6,
                       pd.Timestamp("2026-03-08T10:30:00Z").value//10**6])
        local = localize(ts) + 9*3600*1000
        self.assertEqual((local[1]-local[0])//3600000, 2)

    def test_activation_and_participant_label(self):
        frame = pd.DataFrame({k:[1.,2.,None] for k in ITEMS})
        clean, scores = activation_score(frame)
        self.assertEqual(len(clean), 2)
        np.testing.assert_array_equal(scores.to_numpy(), [1.,2.])
        np.testing.assert_array_equal(label_high(scores.to_numpy(), np.array(["p","p"])), [0,1])


if __name__ == "__main__": unittest.main()
