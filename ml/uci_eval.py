"""Frozen UC Irvine evaluation protocol (TODO 5.6–5.8); prints aggregate scores only."""
import json
from pathlib import Path
import numpy as np
import pandas as pd
from sklearn.metrics import balanced_accuracy_score, roc_auc_score
import train
from export import predict
from features import FEATURES

ROOT=Path(__file__).resolve().parents[1]
FEATURE_DIR=ROOT/"data/features"
UCI=FEATURE_DIR/"v1_UCI.csv"
PARAMS=ROOT/"app/Harmony/Resources/model_params.json"

def metric(y,p): return train.scores(np.asarray(y),np.asarray(p))
def fixed_probs(table,params,columns):
    pos=[params["features"].index(c) for c in columns]
    return np.asarray([predict(params,row[pos]) for row in table[list(params["features"])].to_numpy(float)])

def main():
    uci=pd.read_csv(UCI); y=uci[train.LABEL].to_numpy()
    params=json.loads(PARAMS.read_text(encoding="utf-8"))
    if params["features"] != list(FEATURES):
        raise ValueError("model_params.json feature order differs from features.FEATURES")
    print("Single test UC Irvine",len(uci),uci.participant.nunique(),"responses/participants")
    ep= fixed_probs(uci,params,FEATURES)
    print("EmoPhone final fixed",*(f"{v:.3f}" for v in metric(y,ep)))
    waves=train.load(FEATURE_DIR,("D1","D2","D3"))
    for name in ("time only","time + HR"):
        cols=train.VARIANTS[name]; model=train.make_model().fit(waves[list(cols)].to_numpy(float),waves[train.LABEL].to_numpy())
        print(name,"trained on EmoPhone, tested once",*(f"{v:.3f}" for v in metric(y,model.predict_proba(uci[list(cols)].to_numpy(float))[:,1])))
    splits=train.folds(uci.participant)
    print("5-fold grouped CV",len(uci),uci.participant.nunique())
    fixed_folds=[]
    for _,test in splits:
        fixed_folds.append(metric(y[test],ep[test]))
    print("EmoPhone fixed",f"AUROC {np.mean(np.array(fixed_folds)[:,0]):.3f} +/- {np.std(np.array(fixed_folds)[:,0]):.3f}",f"balanced accuracy {np.mean(np.array(fixed_folds)[:,1]):.3f} +/- {np.std(np.array(fixed_folds)[:,1]):.3f}")
    cv_results={}
    for name,cols in train.VARIANTS.items():
        results=[]
        for tr,te in splits:
            model=train.make_model().fit(uci.iloc[tr][list(cols)].to_numpy(float),y[tr])
            results.append(metric(y[te],model.predict_proba(uci.iloc[te][list(cols)].to_numpy(float))[:,1]))
        a=np.asarray(results); cv_results[name]=a
        print(name,f"AUROC {a[:,0].mean():.3f} +/- {a[:,0].std():.3f}",f"balanced accuracy {a[:,1].mean():.3f} +/- {a[:,1].std():.3f}")
    full=cv_results["time + HR + steps + sleep"]; fixed=np.asarray(fixed_folds)
    hour=cv_results["time only"]
    passed=(full[:,0].mean()>=fixed[:,0].mean()+.02 and full[:,1].mean()>=fixed[:,1].mean() and full[:,0].mean()>hour[:,0].mean())
    print("Same folds: EmoPhone fixed vs UCI 13 features")
    print("EmoPhone",f"AUROC {fixed[:,0].mean():.3f} +/- {fixed[:,0].std():.3f}",f"balanced accuracy {fixed[:,1].mean():.3f} +/- {fixed[:,1].std():.3f}")
    print("UCI 13",f"AUROC {full[:,0].mean():.3f} +/- {full[:,0].std():.3f}",f"balanced accuracy {full[:,1].mean():.3f} +/- {full[:,1].std():.3f}")
    print("Criterion", "replace EmoPhone" if passed else "keep EmoPhone")
    d3=train.load(FEATURE_DIR,("D3",)); model=train.make_model().fit(uci[list(FEATURES)].to_numpy(float),y)
    p=model.predict_proba(d3[list(FEATURES)].to_numpy(float))[:,1]
    print("Information only: UCI all -> EmoPhone D3",len(d3),d3.participant.nunique(),*(f"{v:.3f}" for v in metric(d3[train.LABEL],p)))

if __name__=="__main__": main()
