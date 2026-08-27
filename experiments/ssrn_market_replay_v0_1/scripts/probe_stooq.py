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
    for provider_symbol, symbol in SYMBOLS.items():
        r = requests.get(
            URL,
            params={"s": provider_symbol.lower(), "d1": "20200101", "d2": "20251231", "i": "d"},
            timeout=60,
            headers={"User-Agent": "world8-ssrn-replication/0.1"},
        )
        r.raise_for_status()
        text = r.text
        df = pd.read_csv(io.StringIO(text))
        required = {"Date", "Open", "High", "Low", "Close", "Volume"}
        ok = required.issubset(df.columns) and len(df) > 500
        out.append({
            "symbol": symbol,
            "provider_symbol": provider_symbol,
            "http": r.status_code,
            "rows": int(len(df)),
            "columns": list(df.columns),
            "first_date": str(df.iloc[0]["Date"]) if len(df) else None,
            "last_date": str(df.iloc[-1]["Date"]) if len(df) else None,
            "schema_ok": bool(ok),
        })
        if not ok:
            raise SystemExit(f"invalid Stooq response for {provider_symbol}: {out[-1]}")
    p = Path(__file__).resolve().parents[1] / "results" / "stooq_probe.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps({"provider": "Stooq", "status": "OK", "symbols": out}, indent=2) + "\n")
    print(p.read_text())


if __name__ == "__main__":
    main()
