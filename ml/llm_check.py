"""LLM song scores: shared request format and offline check (TODO 2.29, 2.30).

Usage: python ml/llm_check.py [--db data/muse/muse.sqlite] [--out data/llm_check] [--n 2000]
       [--seed 0] [--part dev|test] [--effort low|medium] [--shrink K_ENERGY K_POSITIVITY]
Needs ANTHROPIC_API_KEY. Trials 1-2 use --n/--seed. Trial 3 uses --part (PROJECT.md §7): a dev
sample of 1,000 songs to choose the effort, then a test sample of 2,000 never-seen songs, both
without the reference songs of the prompt (ml/llm_anchors.py) and the songs of trials 1-2. Sends a seeded sample of MuSe titles and artists (never their scores)
through the Message Batches API (half price), waits for the batch, then prints aggregates only:
correlation and mean error of the LLM scores against MuSe, and the TODO 2.31 rule. The batch ID,
sample and raw answers are kept in --out (under data/, ignored by Git), so a rerun resumes.

The Cloudflare Worker (worker/src/prompt.ts) sends exactly the same request: system prompt
ml/prompts/score.txt, settings ml/prompts/score_config.json, one line per song
"index<TAB>title<TAB>artist1, artist2". The answer is {"s": [{"i": index, "e": energy,
"p": positivity}, ...]} with integers 0-100, divided by 100 here (objects since trial 3: the schema
then forces the index; trials 1-2 used [index, energy, positivity] triples, see their commits). Shared cases: ml/fixtures/score_cases.json.
"""

import argparse
import json
import re
import sqlite3
import time
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
PROMPTS = ROOT / "ml" / "prompts"
_CONTROL = re.compile(r"[\x00-\x1f\x7f]+")
BATCH = 50
# Claude Haiku 5.5 through the Batch API: half of US$0.10 / US$0.50 per million input / output
# tokens (prompts under 100K tokens). Output tokens include thinking.
PRICE_IN, PRICE_OUT = 0.05 / 1e6, 0.25 / 1e6
# Prompt caching (system prompt over 512 tokens): writes cost 1.25x the input price, reads 0.1x.
CACHE_WRITE, CACHE_READ = 1.25, 0.1
# Trial 3 samples (PROJECT.md §7): one seeded draw split into dev and test.
TRIAL3_SEED, TRIAL3_DEV, TRIAL3_TEST = 2, 1000, 2000
TAG_BINS, TAG_LABELS = [0, 1, 3, 9, 10_000], ["1 tag", "2-3 tags", "4-9 tags", ">=10 tags"]
# TODO 2.31 rule, written before the run: a score is used only if both hold (PROJECT.md §7).
RULE_SPEARMAN, RULE_MAE_PCT = 0.4, 0.25


def load_prompt() -> str:
    return (PROMPTS / "score.txt").read_text(encoding="utf-8")


def load_config() -> dict:
    return json.loads((PROMPTS / "score_config.json").read_text(encoding="utf-8"))


def _clean(text: str) -> str:
    return _CONTROL.sub(" ", text)


def user_message(songs: list[dict]) -> str:
    """One line per song: index, title, artists (control characters become a space)."""
    return "\n".join(
        f"{i}\t{_clean(song['title'])}\t{', '.join(_clean(a) for a in song['artists'])}"
        for i, song in enumerate(songs)
    )


def request_params(songs: list[dict], effort: str | None = None) -> dict:
    """Messages API parameters for one batch of at most 50 songs (same as the Worker).

    effort overrides the shared setting, only to compare the two effort levels of trial 3."""
    config = load_config()
    return {
        "model": config["model"],
        "max_tokens": config["max_tokens"],
        "system": [{"type": "text", "text": load_prompt(), "cache_control": {"type": "ephemeral"}}],
        "messages": [{"role": "user", "content": user_message(songs)}],
        "output_config": {"effort": effort or config["effort"],
                          "format": {"type": "json_schema", "schema": config["output_schema"]}},
    }


def _score(value) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and 0 <= value <= 100


def parse_scores(text: str, count: int) -> list[dict | None]:
    """{"energy", "positivity"} in 0..1 per song, or None when the answer has no single valid item."""
    try:
        items = json.loads(text).get("s")
    except (ValueError, AttributeError):
        return [None] * count
    if not isinstance(items, list):
        return [None] * count
    found: dict[int, list] = {}
    for item in items:
        i = item.get("i") if isinstance(item, dict) else None
        if isinstance(i, int) and not isinstance(i, bool) and 0 <= i < count:
            found.setdefault(i, []).append(item)
    result = []
    for i in range(count):
        matches = found.get(i, [])
        ok = len(matches) == 1 and set(matches[0]) == {"i", "e", "p"} \
            and _score(matches[0]["e"]) and _score(matches[0]["p"])
        result.append({"energy": matches[0]["e"] / 100, "positivity": matches[0]["p"] / 100} if ok else None)
    return result


def sample_songs(db: Path, n: int, seed: int) -> pd.DataFrame:
    """n MuSe songs drawn with a fixed seed: title, artists (one MuSe text field), scores."""
    with sqlite3.connect(db) as con:
        songs = pd.read_sql("SELECT title, artists, energy, positivity, match_key FROM songs "
                            "ORDER BY match_key", con)
    return songs.sample(n=n, random_state=seed).reset_index(drop=True)


def trial3_samples(songs: pd.DataFrame, anchors: pd.DataFrame,
                   earlier: list[pd.DataFrame]) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Dev and test samples of trial 3: no reference song of the prompt, no song of trials 1-2."""
    used = set(anchors["match_key"]).union(*(set(s["match_key"]) for s in earlier))
    pool = songs[~songs["match_key"].isin(used)].sort_values("match_key").reset_index(drop=True)
    drawn = pool.sample(n=TRIAL3_DEV + TRIAL3_TEST, random_state=TRIAL3_SEED).reset_index(drop=True)
    return drawn.iloc[:TRIAL3_DEV].reset_index(drop=True), drawn.iloc[TRIAL3_DEV:].reset_index(drop=True)


def batch_requests(sample: pd.DataFrame, effort: str | None = None) -> list[dict]:
    """One Batch request per 50 songs, with titles and artists only."""
    return [
        {"custom_id": f"chunk-{start // BATCH:03d}",
         "params": request_params([{"title": row.title, "artists": [row.artists]}
                                   for row in sample.iloc[start:start + BATCH].itertuples()], effort)}
        for start in range(0, len(sample), BATCH)
    ]


def llm_scores(n: int, results: list[dict]) -> pd.DataFrame:
    """energy/positivity per sampled song (NaN when the LLM gave no valid pair or the request failed)."""
    out = pd.DataFrame(np.nan, index=range(n), columns=["energy", "positivity"])
    for row in results:
        start = int(row["custom_id"].split("-")[1]) * BATCH
        count = min(BATCH, n - start)
        if row["type"] != "succeeded" or row.get("stop_reason") != "end_turn":
            continue
        for offset, pair in enumerate(parse_scores(row["text"], count)):
            if pair:
                out.loc[start + offset] = [pair["energy"], pair["positivity"]]
    return out


def metrics(llm: pd.Series, muse: pd.Series) -> dict:
    """Agreement of one LLM score with MuSe on the songs the LLM scored."""
    ok = llm.notna()
    a, b = llm[ok], muse[ok]
    as_percentile = a.rank(pct=True)          # LLM scores mapped onto a 0-1 percentile scale
    return {
        "scored": int(ok.sum()), "share_null": float(1 - ok.mean()),
        "pearson": a.corr(b), "spearman": a.corr(b, method="spearman"),
        "mae": (a - b).abs().mean(), "mae_pct": (as_percentile - b).abs().mean(),
        "mean_llm": a.mean(), "sd_llm": a.std(), "mean_muse": b.mean(), "sd_muse": b.std(),
    }


def use_llm(m: dict) -> bool:
    return bool(m["spearman"] >= RULE_SPEARMAN and m["mae_pct"] < RULE_MAE_PCT)


def shrunk_mae(llm: pd.Series, muse: pd.Series, k: float) -> float:
    """Secondary: MAE of the percentile LLM scores pulled toward 0.5 (0.5 + k * (score - 0.5))."""
    ok = llm.notna()
    return float((0.5 + k * (llm[ok].rank(pct=True) - 0.5) - muse[ok]).abs().mean())


def best_shrink(llm: pd.Series, muse: pd.Series) -> float:
    """Secondary: the k in 0, 0.05, ..., 1 with the lowest shrunk MAE (chosen on the dev sample)."""
    return min(np.round(np.arange(0, 1.0001, 0.05), 2), key=lambda k: shrunk_mae(llm, muse, k))


def _fetch_results(client, batch_id: str) -> list[dict]:
    rows = []
    for result in client.messages.batches.results(batch_id):
        row = {"custom_id": result.custom_id, "type": result.result.type}
        if result.result.type == "succeeded":
            message = result.result.message
            row.update(stop_reason=message.stop_reason,
                       text=next((b.text for b in message.content if b.type == "text"), ""),
                       input_tokens=message.usage.input_tokens,
                       cache_write_tokens=message.usage.cache_creation_input_tokens or 0,
                       cache_read_tokens=message.usage.cache_read_input_tokens or 0,
                       output_tokens=message.usage.output_tokens)
        rows.append(row)
    return rows


def report(sample: pd.DataFrame, results: list[dict], shrink: list[float] | None = None) -> None:
    ok = [r for r in results if r["type"] == "succeeded"]
    tokens_in = sum(r["input_tokens"] for r in ok)
    cache_write = sum(r.get("cache_write_tokens", 0) for r in ok)
    cache_read = sum(r.get("cache_read_tokens", 0) for r in ok)
    tokens_out = sum(r["output_tokens"] for r in ok)
    cut = sum(r.get("stop_reason") != "end_turn" for r in ok)
    cost = (tokens_in + CACHE_WRITE * cache_write + CACHE_READ * cache_read) * PRICE_IN \
        + tokens_out * PRICE_OUT
    print(f"Requests: {len(results)}, succeeded {len(ok)}, failed {len(results) - len(ok)}, "
          f"not end_turn {cut}")
    print(f"Tokens: {tokens_in} in, {cache_write} cache write, {cache_read} cache read, "
          f"{tokens_out} out (per song {tokens_out / len(sample):.1f} out); cost US${cost:.4f}")
    llm = llm_scores(len(sample), results)
    print(f"Rule 2.31: Spearman >= {RULE_SPEARMAN} and MAE after percentile conversion < {RULE_MAE_PCT}")
    for score in ("energy", "positivity"):
        m = metrics(llm[score], sample[score])
        print(f"{score:>10}: scored {m['scored']} (null {m['share_null']:.1%}), "
              f"Pearson {m['pearson']:.3f}, Spearman {m['spearman']:.3f}, "
              f"MAE {m['mae']:.3f}, MAE percentile {m['mae_pct']:.3f}, "
              f"LLM mean {m['mean_llm']:.3f} SD {m['sd_llm']:.3f}, "
              f"MuSe mean {m['mean_muse']:.3f} SD {m['sd_muse']:.3f} -> "
              f"{'use the LLM' if use_llm(m) else 'neutral 0.5'}")
    print("Secondary (not part of the rule):")
    for i, score in enumerate(("energy", "positivity")):
        line = f"{score:>10}: best shrink k on this sample {best_shrink(llm[score], sample[score]):.2f}"
        if shrink is not None:
            line += (f", MAE percentile shrunk with k={shrink[i]:.2f}: "
                     f"{shrunk_mae(llm[score], sample[score], shrink[i]):.3f}")
        if "tags" in sample:
            bins = pd.cut(sample["tags"], TAG_BINS, labels=TAG_LABELS)
            line += " | Spearman " + ", ".join(
                f"{label} (n={int((bins == label).sum())}) "
                f"{llm[score][bins == label].corr(sample[score][bins == label], method='spearman'):.3f}"
                for label in TAG_LABELS)
        print(line)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--db", type=Path, default=ROOT / "data" / "muse" / "muse.sqlite")
    parser.add_argument("--out", type=Path, default=ROOT / "data" / "llm_check")
    parser.add_argument("--n", type=int, default=2000)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--part", choices=["dev", "test"], help="trial 3 sample (ignores --n/--seed)")
    parser.add_argument("--csv", type=Path, default=ROOT / "data" / "muse" / "muse_v3.csv")
    parser.add_argument("--effort", choices=["low", "medium"], help="overrides score_config.json")
    parser.add_argument("--shrink", type=float, nargs=2, metavar=("K_ENERGY", "K_POSITIVITY"),
                        help="secondary: shrink factors chosen on the dev sample")
    args = parser.parse_args()

    import anthropic                                   # only needed for the real run
    client = anthropic.Anthropic()
    args.out.mkdir(parents=True, exist_ok=True)
    state_path, sample_path = args.out / "batch.json", args.out / "sample.json"
    results_path = args.out / "results.jsonl"

    if state_path.exists():
        batch_id = json.loads(state_path.read_text())["batch_id"]
        sample = pd.read_json(sample_path, orient="records")
        print(f"Resuming batch {batch_id}")
    else:
        if args.part:
            from llm_anchors import muse_with_tags, select_anchors
            songs = muse_with_tags(args.db, args.csv)
            earlier = [sample_songs(args.db, 2000, seed) for seed in (0, 1)]
            dev, test = trial3_samples(songs, select_anchors(songs), earlier)
            sample = dev if args.part == "dev" else test
        else:
            sample = sample_songs(args.db, args.n, args.seed)
        sample.to_json(sample_path, orient="records", force_ascii=False)
        batch = client.messages.batches.create(requests=batch_requests(sample, args.effort))
        batch_id = batch.id
        state_path.write_text(json.dumps({"batch_id": batch_id, "n": len(sample), "seed": args.seed,
                                          "part": args.part, "effort": args.effort}))
        print(f"Batch {batch_id} submitted: {len(sample)} songs")

    while (batch := client.messages.batches.retrieve(batch_id)).processing_status != "ended":
        print(f"{batch.processing_status}: {batch.request_counts.processing} requests left")
        time.sleep(60)

    if not results_path.exists():
        rows = _fetch_results(client, batch_id)
        results_path.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows))
    results = [json.loads(line) for line in results_path.read_text().splitlines()]
    report(sample, results, args.shrink)


if __name__ == "__main__":
    main()
