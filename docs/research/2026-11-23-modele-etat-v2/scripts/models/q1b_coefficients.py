"""Q1 complement: standardized LR (C=1) coefficients per target, mean +/- sd over the 5
training folds of ml/train.py (model weights only; aggregates)."""
import numpy as np

from common import F13, TARGETS, load_table, splits_of, train

table = load_table()
splits = splits_of(table)
X = table[F13].to_numpy(float)
print("standardized coefficients (median-imputed, scaled inputs), mean +/- sd over 5 folds")
print(f"{'feature':<18}" + "".join(f"{k:>20}" for k in TARGETS))
coef = {}
for k in TARGETS:
    y = table[f"{k}_high"].to_numpy()
    coef[k] = np.array([train.make_model().fit(X[tr], y[tr])[-1].coef_[0] for tr, _ in splits])
for i, f in enumerate(F13):
    print(f"{f:<18}" + "".join(f"{coef[k][:, i].mean():>+12.3f} +/-{coef[k][:, i].std():.3f}"
                                for k in TARGETS))
for k in TARGETS:
    print(f"intercept-free L2 norm {k}: {np.linalg.norm(coef[k].mean(0)):.3f}")
