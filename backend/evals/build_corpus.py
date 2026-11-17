"""Build evals/corpus.json: a fixed slice of real UHRI recommendations for the offline eval.

The full UHRI export is about 380 MB and changes daily, so the eval runs on a committed slice.
Download the export once, then run from backend/:

    curl -o /tmp/uhri.json https://dataex.ohchr.org/uhri/export-results/export-full-en.json
    PYTHONPATH=. uv run python evals/build_corpus.py /tmp/uhri.json

Selection is deterministic: recommendations about exactly one of COUNTRIES, published from
MIN_YEAR, with text of a readable length. For each country it takes PER_COUNTRY records,
cycling through themes so no single theme dominates.
"""

import json
import sys
from collections import defaultdict
from itertools import zip_longest
from pathlib import Path

from src.app.ai.tools.uhri_client import normalize_export_record

COUNTRIES = ("Kenya", "Brazil", "India", "Mexico", "Philippines", "Nigeria", "Ukraine", "Colombia")
PER_COUNTRY = 60
MIN_YEAR = "2015"
TEXT_LENGTH = range(60, 900)
OUTPUT = Path(__file__).resolve().parent / "corpus.json"


def is_candidate(record: dict) -> bool:
    return (
        record["annotation_type"] == "Recommendations"
        and record["country"] in COUNTRIES
        and record["year"] >= MIN_YEAR
        and bool(record["theme"])
        and len(record["recommendation"]) in TEXT_LENGTH
    )


def select(records: list[dict]) -> list[dict]:
    by_country_theme: dict[str, dict[str, list[dict]]] = defaultdict(lambda: defaultdict(list))
    for record in sorted(records, key=lambda r: r["id"]):
        first_theme = record["theme"].split("; ")[0]
        by_country_theme[record["country"]][first_theme].append(record)

    corpus = []
    for country in COUNTRIES:
        themes = by_country_theme[country]
        round_robin = (r for batch in zip_longest(*(themes[t] for t in sorted(themes))) for r in batch if r)
        picked = [r for _, r in zip(range(PER_COUNTRY), round_robin, strict=False)]
        if len(picked) < PER_COUNTRY:
            raise SystemExit(f"Only {len(picked)} candidate records for {country}")
        corpus.extend(picked)
    return corpus


def main(export_path: str) -> None:
    records = [normalize_export_record(r) for r in json.loads(Path(export_path).read_text())]
    corpus = select([r for r in records if is_candidate(r)])
    OUTPUT.write_text(json.dumps(corpus, indent=1, ensure_ascii=False) + "\n")
    print(f"Wrote {len(corpus)} records to {OUTPUT}")


if __name__ == "__main__":
    main(sys.argv[1])
