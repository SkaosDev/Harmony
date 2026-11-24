"""Compare the fixed WP-A1 candidates. D-3 is only read with --confirm-d3."""
import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
import joblib

from features import FEATURES, FEATURES_V2
from train import folds, make_model, scores

TIME = FEATURES[:3]


def fit(table, columns, target):
    return make_model().fit(table[list(columns)].to_numpy(), table[target + "_high"])


def logits(model, table, columns):
    return model.decision_function(table[list(columns)].to_numpy())


def gate(columns):
    """Body mode needs raw_hr_30 with the 17 features (v2), z_hr_30 with the 13 (v1)."""
    return "raw_hr_30" if tuple(columns) == FEATURES_V2 else "z_hr_30"


def mixed_logits(body, time, table, columns):
    return np.where(table[gate(columns)].notna(), logits(body, table, columns), logits(time, table, TIME))


def evaluate(train, test):
    result = {}
    if set(train.participant) & set(test.participant):
        raise ValueError("training and test participants overlap")
    for target in ("arousal", "valence"):
        time = fit(train, TIME, target)
        variants = {"time": logits(time, test, TIME)}
        for version, columns in (("v1", FEATURES), ("v2", FEATURES_V2)):
            body = fit(train, columns, target)
            variants[version + "_full"] = logits(body, test, columns)
            variants[version + "_app"] = mixed_logits(body, time, test, columns)
        for name, z in variants.items():
            result[f"{target}_{name}"] = scores(test[target + "_high"], 1 / (1 + np.exp(-z)))
    return result


def decision(cv, d3):
    mean = lambda name: np.mean([fold[name][0] for fold in cv])
    auc = lambda name: d3[name][0]
    return {
        "energy_v2": bool(mean("arousal_v2_app") >= mean("arousal_v1_app") - .002
                          and auc("arousal_v2_app") >= auc("arousal_v1_app")
                          and auc("arousal_v2_app") >= auc("arousal_time") + .02),
        "valence_model": bool(mean("valence_v2_app") >= mean("valence_time") + .01
                              and auc("valence_v2_app") >= auc("valence_time") + .01),
    }


def load(folder, wave):
    return pd.read_csv(folder / f"v2_{wave}.csv")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--features", type=Path, default=Path("data/features"))
    parser.add_argument("--confirm-d3", type=Path, help="new aggregate JSON file for the single D-3 result")
    parser.add_argument("--final", nargs=2, type=Path, metavar=("PROOF", "MODEL"),
                        help="train locally after adoption recorded in PROOF")
    args = parser.parse_args()
    table = pd.concat([load(args.features, wave) for wave in ("D1", "D2")], ignore_index=True)
    if args.final:
        if args.confirm_d3:
            parser.error("--final and --confirm-d3 are separate steps")
        proof, output = args.final
        adopted = json.loads(proof.read_text(encoding="utf-8"))["decision"]
        if not adopted["energy_v2"]:
            parser.error("the energy candidate did not pass adoption")
        if not output.resolve().is_relative_to(Path("data").resolve()):
            parser.error("the trained joblib must stay in data/")
        all_waves = pd.concat([table, load(args.features, "D3")], ignore_index=True)
        saved = {"features": list(FEATURES_V2), "label": "arousal_high",
                 "model": fit(all_waves, FEATURES_V2, "arousal"),
                 "time_only_features": list(TIME), "time_only": fit(all_waves, TIME, "arousal")}
        if adopted["valence_model"]:
            # Adopted rule ("valence_v2_app"): valence model if raw_hr_30 is known, else time only.
            saved["valence"] = fit(all_waves, FEATURES_V2, "valence")
            saved["valence_time_only"] = fit(all_waves, TIME, "valence")
        output.parent.mkdir(parents=True, exist_ok=True)
        joblib.dump(saved, output)
        return
    if args.confirm_d3 and args.confirm_d3.exists():
        parser.error(f"{args.confirm_d3} exists: D-3 is evaluated only once")
    cv = [evaluate(table.iloc[train], table.iloc[test]) for train, test in folds(table.participant)]
    for name in cv[0]:
        values = np.array([fold[name] for fold in cv])
        print(f"{name:20} AUROC {values[:, 0].mean():.6f} ± {values[:, 0].std():.6f}"
              f" | BA {values[:, 1].mean():.6f} ± {values[:, 1].std():.6f}")
    if args.confirm_d3:
        # Compute first: an error must not leave an empty proof file that blocks the retry.
        d3 = evaluate(table, load(args.features, "D3"))
        result = {"cv": cv, "d3": d3, "decision": decision(cv, d3)}
        args.confirm_d3.parent.mkdir(parents=True, exist_ok=True)
        with args.confirm_d3.open("x", encoding="utf-8") as proof:
            json.dump(result, proof, indent=2)
        print(json.dumps({"d3": d3, "decision": result["decision"]}, indent=2))


if __name__ == "__main__":
    main()
