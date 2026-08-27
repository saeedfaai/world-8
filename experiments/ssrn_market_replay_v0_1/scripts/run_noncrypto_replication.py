from __future__ import annotations

import calendar
import datetime as dt
import gzip
import hashlib
import json
from pathlib import Path
import sys

import pandas as pd
import requests

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.noncrypto import run_daily_symbol

SYMBOLS = ["SPY", "QQQ", "GLD"]
URL = "https://query1.finance.yahoo.com/v8/finance/chart/{symbol}"
DATA_DIR = ROOT / "data" / "noncrypto_frozen"
RESULTS = ROOT / "results"
DATA_DIR.mkdir(parents=True, exist_ok=True)
RESULTS.mkdir(parents=True, exist_ok=True)


def epoch(y, m, d):
    return calendar.timegm(dt.datetime(y, m, d, tzinfo=dt.timezone.utc).timetuple())


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_gzip_deterministic(data: bytes, path: Path):
    path.write_bytes(gzip.compress(data, compresslevel=9, mtime=0))


def download_symbol(symbol: str) -> tuple[pd.DataFrame, dict]:
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
    r.raise_for_status()
    payload = r.json()
    result = payload["chart"]["result"][0]
    ts = result["timestamp"]
    quote = result["indicators"]["quote"][0]
    df = pd.DataFrame({
        "timestamp": ts,
        "open": quote["open"],
        "high": quote["high"],
        "low": quote["low"],
        "close": quote["close"],
        "volume": quote["volume"],
    })
    df = df.dropna(subset=["open", "high", "low", "close", "volume"]).copy()
    df["open_time"] = pd.to_datetime(df["timestamp"], unit="s", utc=True)
    df = df[["open_time", "open", "high", "low", "close", "volume"]].sort_values("open_time").reset_index(drop=True)

    csv = df.to_csv(index=False, float_format="%.10g", lineterminator="\n").encode()
    out_path = DATA_DIR / f"{symbol}_1d_2020_2025.csv.gz"
    write_gzip_deterministic(csv, out_path)
    normalized_sha = sha256_bytes(out_path.read_bytes())

    receipt = {
        "symbol": symbol,
        "provider": "Yahoo Finance chart API",
        "requested_url": r.url,
        "http": r.status_code,
        "content_type": r.headers.get("content-type"),
        "source_response_sha256": sha256_bytes(r.content),
        "normalized_gzip_sha256": normalized_sha,
        "rows": int(len(df)),
        "first_timestamp": df.iloc[0]["open_time"].isoformat(),
        "last_timestamp": df.iloc[-1]["open_time"].isoformat(),
        "provider_checksum_available": False,
    }
    return df, receipt


def load_frozen(symbol: str) -> pd.DataFrame:
    p = DATA_DIR / f"{symbol}_1d_2020_2025.csv.gz"
    df = pd.read_csv(p, compression="gzip")
    df["open_time"] = pd.to_datetime(df["open_time"], utc=True)
    return df


def write_jsonl_gz(rows, path: Path):
    raw = b"".join((json.dumps(r, sort_keys=True, separators=(",", ":")) + "\n").encode() for r in rows)
    write_gzip_deterministic(raw, path)


def main():
    source_receipts = []
    for symbol in SYMBOLS:
        _, receipt = download_symbol(symbol)
        source_receipts.append(receipt)

    metrics = []
    boot = []
    weights = {}
    contracts = []
    for symbol in SYMBOLS:
        out = run_daily_symbol(load_frozen(symbol), symbol)
        metrics.extend(out["metrics"])
        boot.append(out["bootstrap"])
        weights[symbol] = out["weights"]
        contracts.extend(out["contracts"])

    pd.DataFrame(metrics).to_csv(RESULTS / "noncrypto_metrics.csv", index=False, float_format="%.12g", lineterminator="\n")
    pd.DataFrame(boot).to_csv(RESULTS / "noncrypto_bootstrap.csv", index=False, float_format="%.12g", lineterminator="\n")
    write_jsonl_gz(contracts, RESULTS / "noncrypto_forecast_contracts.jsonl.gz")

    manifest = {
        "schema": "WORLD8_NONCRYPTO_SNAPSHOT/1.0",
        "status": "FROZEN_NORMALIZED_WITH_LOCAL_HASHES",
        "provider": "Yahoo Finance chart API",
        "provider_checksum_available": False,
        "note": "Independent replication uses normalized local SHA256 because this endpoint does not publish provider checksum files analogous to Binance Data Vision.",
        "symbols": source_receipts,
    }
    (DATA_DIR / "snapshot_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")

    summary = {
        "schema": "WORLD8_NONCRYPTO_REPLICATION_RESULT/1.0",
        "status": "INDEPENDENT_NONCRYPTO_REPLICATION_COMPLETE",
        "market_class": "US_ETF",
        "frequency": "1d",
        "symbols": SYMBOLS,
        "data_window": ["2020-01-01", "2025-12-31"],
        "calibration_window": ["2023-01-01", "2024-12-31"],
        "test_window": ["2025-01-01", "2025-12-31"],
        "event": "close[t+5 trading bars] > close[t]",
        "weights": weights,
        "source_manifest": "data/noncrypto_frozen/snapshot_manifest.json",
        "files": {
            "metrics": "results/noncrypto_metrics.csv",
            "bootstrap": "results/noncrypto_bootstrap.csv",
            "contracts": "results/noncrypto_forecast_contracts.jsonl.gz",
        },
    }
    (RESULTS / "noncrypto_summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
