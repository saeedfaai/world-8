from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]
manifest = (ROOT / "architecture" / "WORLD8_ARCHITECTURE.yaml").read_text(encoding="utf-8")
required = [
    "WORLD8_ARCHITECTURE_MANIFEST/1.0",
    "Parallelize work; serialize truth",
    "binding-contract-v1",
    "canonical-boundary-v1",
    "composition-contract-v1",
    "development-control-plane-contract-v1",
    "resolver-contract-v1",
]
missing = [x for x in required if x not in manifest]
if missing:
    raise SystemExit(f"Architecture manifest missing required markers: {missing}")
contracts = list((ROOT / "architecture" / "contracts").glob("*.yaml"))
if len(contracts) < 5:
    raise SystemExit("Expected at least 5 frozen contract files")
print("World 8 architecture bootstrap validation PASS")
print("manifest_sha256=", hashlib.sha256(manifest.encode()).hexdigest())
