from __future__ import annotations

import argparse
import hashlib
import json
import re
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable


FORBIDDEN_W8P02_MARKERS = [
    "BTCUSDT", "ETHUSDT", "SOLUSDT",
    "-0.016393", "-0.013569", "-0.012082",
    "-0.02385937", "-0.02453994", "-0.00430077",
    "52,920 RESOLVED", "52920 RESOLVED",
]

ALLOWED_BOILERPLATE_PREFIXES = (
    "ai-assisted tools were used",
    "saeed farokhi",
    "mechanical engineering, university of tehran",
    "corresponding author:",
)


@dataclass
class Paragraph:
    index: int
    raw: str
    normalized: str
    words: list[str]


def normalize(text: str) -> str:
    text = re.sub(r"[`*_>#|]", " ", text.lower())
    text = re.sub(r"https?://\S+", " <url> ", text)
    text = re.sub(r"\[[0-9,\- ]+\]", " <cite> ", text)
    text = re.sub(r"[^a-z0-9<>=.!?+\-/ ]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def body_before_references(text: str) -> str:
    # Bibliographies are expected to overlap by citation and are not duplicate Results.
    m = re.search(r"^##\s+References\s*$", text, flags=re.I | re.M)
    return text[:m.start()] if m else text


def paragraphs(text: str) -> list[Paragraph]:
    text = body_before_references(text)
    chunks = re.split(r"\n\s*\n", text)
    out: list[Paragraph] = []
    for raw in chunks:
        raw = raw.strip()
        if not raw or raw.startswith("#"):
            continue
        norm = normalize(raw)
        if not norm:
            continue
        if norm.startswith(ALLOWED_BOILERPLATE_PREFIXES):
            continue
        words = norm.split()
        out.append(Paragraph(len(out), raw, norm, words))
    return out


def shingles(words: list[str], n: int = 8) -> set[tuple[str, ...]]:
    if len(words) < n:
        return set()
    return {tuple(words[i:i+n]) for i in range(len(words)-n+1)}


def jaccard(a: set, b: set) -> float:
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def table_rows(text: str) -> set[str]:
    rows = set()
    for line in body_before_references(text).splitlines():
        s = line.strip()
        if s.startswith("|") and s.endswith("|") and re.search(r"\d", s):
            rows.add(normalize(s))
    return rows


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--p01", type=Path, required=True)
    ap.add_argument("--p02", type=Path, required=True)
    ap.add_argument("--json-out", type=Path, required=True)
    ap.add_argument("--md-out", type=Path, required=True)
    args = ap.parse_args()

    p01_text = args.p01.read_text(encoding="utf-8")
    p02_text = args.p02.read_text(encoding="utf-8")
    p01 = paragraphs(p01_text)
    p02 = paragraphs(p02_text)

    exact = []
    near = []
    p02_by_norm = {p.normalized: p for p in p02}

    for a in p01:
        if len(a.words) >= 50 and a.normalized in p02_by_norm:
            b = p02_by_norm[a.normalized]
            exact.append({"p01_index": a.index, "p02_index": b.index, "words": len(a.words), "text": a.raw[:600]})

    p02_sh = [(b, shingles(b.words)) for b in p02 if len(b.words) >= 50]
    for a in p01:
        if len(a.words) < 50:
            continue
        sa = shingles(a.words)
        best = None
        for b, sb in p02_sh:
            score = jaccard(sa, sb)
            if best is None or score > best[0]:
                best = (score, b)
        if best and best[0] >= 0.80:
            near.append({
                "p01_index": a.index,
                "p02_index": best[1].index,
                "score": round(best[0], 6),
                "p01_words": len(a.words),
                "p02_words": len(best[1].words),
                "p01_text": a.raw[:600],
                "p02_text": best[1].raw[:600],
            })

    forbidden = []
    p01_body = body_before_references(p01_text)
    for marker in FORBIDDEN_W8P02_MARKERS:
        if marker.lower() in p01_body.lower():
            forbidden.append(marker)

    shared_table_rows = sorted(table_rows(p01_text) & table_rows(p02_text))

    # High-similarity long prose is a blocker; lower near-matches remain visible for human review.
    high_near = [x for x in near if x["score"] >= 0.95]
    blockers = {
        "exact_long_paragraph_reuse": exact,
        "near_duplicate_long_paragraphs_ge_0_95": high_near,
        "forbidden_w8p02_result_markers": forbidden,
        "shared_numeric_table_rows": shared_table_rows,
    }
    blocker_count = sum(len(v) for v in blockers.values())

    result = {
        "schema": "WORLD8_W8P01_P02_POST_DRAFT_OVERLAP_AUDIT/1.0",
        "p01": {"path": str(args.p01), "sha256": sha256_text(p01_text), "paragraphs": len(p01)},
        "p02": {"path": str(args.p02), "sha256": sha256_text(p02_text), "paragraphs": len(p02)},
        "method": {
            "references_excluded": True,
            "boilerplate_excluded": list(ALLOWED_BOILERPLATE_PREFIXES),
            "exact_min_words": 50,
            "near_metric": "Jaccard over normalized 8-word shingles",
            "near_report_threshold": 0.80,
            "near_block_threshold": 0.95,
        },
        "blockers": blockers,
        "near_matches_for_manual_review_ge_0_80": near,
        "blocker_count": blocker_count,
        "gate_state": "PASS" if blocker_count == 0 else "BLOCKED",
        "interpretation": "This audit detects repeated manuscript prose/result material. It does not replace publisher similarity screening or expert judgment.",
    }

    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")

    md = [
        "# W8-P01 ↔ W8-P02 Post-Draft Text Overlap Audit",
        "",
        f"**Gate:** {result['gate_state']}",
        f"**Blockers:** {blocker_count}",
        "",
        "## Blocking checks",
        f"- exact long paragraph reuse: {len(exact)}",
        f"- near-duplicate long paragraphs (>=0.95): {len(high_near)}",
        f"- forbidden W8-P02 result markers in W8-P01: {len(forbidden)}",
        f"- shared numeric table rows: {len(shared_table_rows)}",
        "",
        "## Manual-review near matches (>=0.80)",
    ]
    if near:
        for x in near:
            md.append(f"- score={x['score']:.3f}; P01 paragraph {x['p01_index']}; P02 paragraph {x['p02_index']}; blocker={'YES' if x['score'] >= 0.95 else 'NO'}")
    else:
        md.append("- none")
    md += [
        "",
        "## Scope note",
        "References and limited required boilerplate are excluded. W8-P02 market-performance numbers/tables remain exclusively owned by W8-P02. A PASS here is necessary but not sufficient for publication ethics review.",
    ]
    args.md_out.write_text("\n".join(md) + "\n", encoding="utf-8")

    print(json.dumps(result, indent=2, ensure_ascii=False))
    if result["gate_state"] != "PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
