from __future__ import annotations

import calendar
import datetime as dt
import json
from pathlib import Path

import requests

SYMBOLS = ["SPY", "QQQ", "GLD"]
URL = "https://query1.finance.yahoo.com/v8/finance/chart/{symbol}"


def epoch(y, m, d):
    return calendar.timegm(dt.datetime(y, m, d, tzinfo=dt.timezone.utc).timetuple())


def main():
    out = []
    status = "OK"
    for symbol in SYMBOLS:
        r = requests.get(
            URL.format(symbol=symbol),
            params={
                "period1": epoch(2020, 1, 1),
                "period2": epoch(2026, 1, 1),
                "interval": "1d",
                "events": "history",
                "includeAdjustedClose": "true",
            },
            timeout=60,
            headers={"User-Agent": "Mozilla/5.0 world8-ssrn-replication/0.1"},
        )
        preview = " ".join(r.text[:240].replace("\r", " ").replace("\n", " ").split())
        row = {
            "symbol": symbol,
            "requested_url": r.url,
            "http": r.status_code,
            "content_type": r.headers.get("content-type"),
            "response_preview": preview,
            "rows": 0,
            "schema_ok": False,
            "first_timestamp": None,
            "last_timestamp": None,
        }
        if r.ok:
            try:
                payload = r.json()
                result = payload["chart"]["result"][0]
                ts = result.get("timestamp") or []
                quote = (result.get("indicators") or {}).get("quote", [{}])[0]
                required = all(k in quote for k in ("open", "high", "low", "close", "volume"))
                row["rows"] = len(ts)
                row["schema_ok"] = bool(required and len(ts) > 500)
                if ts:
                    row["first_timestamp"] = dt.datetime.fromtimestamp(ts[0], dt.timezone.utc).isoformat()
                    row["last_timestamp"] = dt.datetime.fromtimestamp(ts[-1], dt.timezone.utc).isoformat()
            except Exception as e:
                row["parse_error_type"] = type(e).__name__
        if not row["schema_ok"]:
            status = "INVALID_SOURCE_RESPONSE"
        out.append(row)

    p = Path(__file__).resolve().parents[1] / "results" / "yahoo_probe.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps({"provider": "Yahoo Finance chart API", "status": status, "symbols": out}, indent=2) + "\n")
    print(p.read_text())
    if status != "OK":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
