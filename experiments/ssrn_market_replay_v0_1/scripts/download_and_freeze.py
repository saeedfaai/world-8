from __future__ import annotations
import gzip
import hashlib
import io
import json
import zipfile
from pathlib import Path

import pandas as pd
import requests
import yaml

ROOT = Path(__file__).resolve().parents[1]
PROTOCOL = yaml.safe_load((ROOT / "PROTOCOL.yaml").read_text())
OUT = ROOT / "data" / "frozen"
OUT.mkdir(parents=True, exist_ok=True)

COLS = [
    "open_time", "open", "high", "low", "close", "volume", "close_time",
    "quote_asset_volume", "number_of_trades", "taker_buy_base_asset_volume",
    "taker_buy_quote_asset_volume", "ignore",
]


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def epoch_to_us(series: pd.Series) -> pd.Series:
    v = pd.to_numeric(series, errors="raise").astype("int64")
    med = int(v.abs().median())
    if med >= 10**15:
        return v
    if med >= 10**12:
        return v * 1000
    raise ValueError(f"unexpected timestamp scale median={med}")


def deterministic_gzip_csv(df: pd.DataFrame, path: Path) -> str:
    raw = df.to_csv(index=False, lineterminator="\n", float_format="%.12g").encode("utf-8")
    packed = gzip.compress(raw, compresslevel=9, mtime=0)
    path.write_bytes(packed)
    return sha256_bytes(packed)


def month_iter(start="2024-01", end="2025-12"):
    cur = pd.Period(start, freq="M")
    stop = pd.Period(end, freq="M")
    while cur <= stop:
        yield cur.year, cur.month
        cur += 1


def download(url: str) -> bytes:
    r = requests.get(url, timeout=120)
    r.raise_for_status()
    return r.content


def freeze_symbol(symbol: str):
    frames = []
    source_files = []
    base = PROTOCOL["data"]["base_url"].rstrip("/")
    interval = PROTOCOL["data"]["interval"]

    for year, month in month_iter():
        name = f"{symbol}-{interval}-{year:04d}-{month:02d}.zip"
        url = f"{base}/{symbol}/{interval}/{name}"
        checksum_url = url + ".CHECKSUM"
        blob = download(url)
        checksum_text = download(checksum_url).decode("utf-8", errors="replace").strip()
        expected = checksum_text.split()[0].lower()
        actual = sha256_bytes(blob)
        if actual != expected:
            raise RuntimeError(f"provider checksum mismatch {name}: {actual} != {expected}")
        source_files.append({"name": name, "url": url, "checksum_url": checksum_url, "sha256": actual, "bytes": len(blob)})

        with zipfile.ZipFile(io.BytesIO(blob)) as zf:
            csv_names = [n for n in zf.namelist() if n.lower().endswith(".csv")]
            if len(csv_names) != 1:
                raise RuntimeError(f"expected one CSV in {name}, got {csv_names}")
            with zf.open(csv_names[0]) as fh:
                df = pd.read_csv(fh, header=None, names=COLS)
        df["open_time_us"] = epoch_to_us(df["open_time"])
        df["close_time_us"] = epoch_to_us(df["close_time"])
        frames.append(df)

    full = pd.concat(frames, ignore_index=True)
    full = full.sort_values("open_time_us").drop_duplicates("open_time_us", keep="last")
    start_us = int(pd.Timestamp(PROTOCOL["data"]["start"]).timestamp() * 1_000_000)
    end_us = int(pd.Timestamp(PROTOCOL["data"]["end_exclusive"]).timestamp() * 1_000_000)
    full = full[(full.open_time_us >= start_us) & (full.open_time_us < end_us)].copy()

    keep = [
        "open_time_us", "close_time_us", "open", "high", "low", "close", "volume",
        "quote_asset_volume", "number_of_trades", "taker_buy_base_asset_volume",
        "taker_buy_quote_asset_volume",
    ]
    full = full[keep]
    for c in ["open", "high", "low", "close", "volume", "quote_asset_volume", "taker_buy_base_asset_volume", "taker_buy_quote_asset_volume"]:
        full[c] = pd.to_numeric(full[c], errors="raise")
    full["number_of_trades"] = pd.to_numeric(full["number_of_trades"], errors="raise").astype("int64")

    expected_step = 3_600_000_000
    diffs = full.open_time_us.diff().dropna().astype("int64")
    discontinuities = diffs[diffs != expected_step]
    expected_rows = int((end_us - start_us) // expected_step)
    path = OUT / f"{symbol}_1h_2024-01_2025-12.csv.gz"
    normalized_sha = deterministic_gzip_csv(full, path)

    return {
        "symbol": symbol,
        "rows": int(len(full)),
        "expected_rows": expected_rows,
        "row_delta": int(len(full) - expected_rows),
        "first_open_time_us": int(full.open_time_us.iloc[0]),
        "last_open_time_us": int(full.open_time_us.iloc[-1]),
        "discontinuity_count": int(len(discontinuities)),
        "normalized_file": str(path.relative_to(ROOT)),
        "normalized_sha256": normalized_sha,
        "source_files": source_files,
    }


def main():
    manifest = {
        "schema": "WORLD8_MARKET_DATA_SNAPSHOT/1.0",
        "provider": "Binance Public Data / Data Vision",
        "protocol": "PROTOCOL.yaml",
        "symbols": [],
    }
    for symbol in PROTOCOL["data"]["symbols"]:
        print(f"freezing {symbol}", flush=True)
        manifest["symbols"].append(freeze_symbol(symbol))
    (OUT / "snapshot_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": "OK", "symbols": [x["symbol"] for x in manifest["symbols"]]}, indent=2))


if __name__ == "__main__":
    main()
