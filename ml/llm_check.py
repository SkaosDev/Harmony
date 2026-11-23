"""LLM song scores: shared request format and offline check (TODO 2.29, 2.30).

The Cloudflare Worker (worker/src/prompt.ts) sends exactly the same request: system prompt
ml/prompts/score.txt, settings ml/prompts/score_config.json, one line per song
"index<TAB>title<TAB>artist1, artist2". The answer is {"s": [[index, energy, positivity], ...]}
with integers 0-100, divided by 100 here. Shared cases: ml/fixtures/score_cases.json.
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROMPTS = ROOT / "ml" / "prompts"
_CONTROL = re.compile(r"[\x00-\x1f\x7f]+")


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


def request_params(songs: list[dict]) -> dict:
    """Messages API parameters for one batch of at most 50 songs (same as the Worker)."""
    config = load_config()
    return {
        "model": config["model"],
        "max_tokens": config["max_tokens"],
        "system": load_prompt(),
        "messages": [{"role": "user", "content": user_message(songs)}],
        "output_config": {"format": {"type": "json_schema", "schema": config["output_schema"]}},
    }


def _score(value) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and 0 <= value <= 100


def parse_scores(text: str, count: int) -> list[dict | None]:
    """{"energy", "positivity"} in 0..1 per song, or None when the answer has no single valid triple."""
    try:
        triples = json.loads(text).get("s")
    except (ValueError, AttributeError):
        return [None] * count
    if not isinstance(triples, list):
        return [None] * count
    found: dict[int, list] = {}
    for triple in triples:
        if isinstance(triple, list) and triple and isinstance(triple[0], int) \
                and not isinstance(triple[0], bool) and 0 <= triple[0] < count:
            found.setdefault(triple[0], []).append(triple)
    result = []
    for i in range(count):
        matches = found.get(i, [])
        ok = len(matches) == 1 and len(matches[0]) == 3 and _score(matches[0][1]) and _score(matches[0][2])
        result.append({"energy": matches[0][1] / 100, "positivity": matches[0][2] / 100} if ok else None)
    return result
