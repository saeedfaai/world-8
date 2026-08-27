from __future__ import annotations

import io
import json
from pathlib import Path

import pandas as pd
import requests

SYMBOLS = {"SPY.US": "SPY", "QQQ.US": "QQQ", "GLD.US": "GLD"}
URL = "https://stooq.com/q/d/l/"


def main():
    out = []
    status = "OK"
    for provider_symbol, symbol in SYMBOLS.items():
        r = requests.get(
            URL,
            params={"s": provider_symbol.lower(), "d1": "20200101", "d2": "20251231", "i": "d"},
            timeout=60,
            headers={"User-Agent": "world8-ssrn-replication/0.1"},
        )
        r.raise_for_status()
        text = r.text
        try:
            df = pd.read_csv(io.StringIO(text))
            columns = list(df.columns)
            rows = int(len(df))
        except Exception as e:
            df = pd.DataFrame()
            columns = []
            rows = 0
        required = {"Date", "Open", "High", "Low", "Close", "Volume"}
        ok = required.issubset(columns) and rows > 500
        preview = " ".join(text[:240].replace("\r", " ").replace("\n", " ").split())
        row = {
            "symbol": symbol,
            "provider_symbol": provider_symbol,
            "requested_url": r.url,
            "http": r.status_code,
            "content_type": r.headers.get("content-type"),
            "rows": rows,
            "columns": columns,
            "response_preview": preview,
            "first_date": str(df.iloc[0]["Date"]) if ok else None,
            "last_date": str(df.iloc[-1]["Date"]) if ok else None,
            "schema_ok": bool(ok),
        }
        out.append(row)
        if not ok:
            status = "INVALID_SOURCE_RESPONSE"

    p = Path(__file__).resolve().parents[1] / "results" / "stooq_probe.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps({"provider": "Stooq", "status": status, "symbols": out}, indent=2) + "\n")
    print(p.read_text())
    if status != "OK":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
