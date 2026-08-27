from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs" / "engineering" / "GROQ_SCALE5_EVIDENCE.md"
FAILOVER = ROOT / "docs" / "engineering" / "PROVIDER_FAILOVER_MESH.md"


def require(text: str, marker: str, label: str) -> None:
    if marker not in text:
        raise SystemExit(f"FAIL: missing {label}: {marker}")


def main() -> None:
    doc = DOC.read_text(encoding="utf-8")
    failover = FAILOVER.read_text(encoding="utf-8")

    require(doc, "SCALE_5_SUCCEEDED", "scale status")
    require(doc, "5_OF_5_SUCCESS", "five-lane success")
    require(doc, "ZERO_FAILURE", "zero-failure evidence")
    require(doc, "CLEAN_RELEASE", "cleanup evidence")
    require(doc, "SCALE_20_ELIGIBLE_NOT_STARTED", "next gate")
    require(doc, "envref:GROQ_API_KEY4", "opaque credential ref")
    require(doc, "provider-health-34c974ca47a12e5822558d94e698", "provider health receipt")

    for lane in range(1, 6):
        require(doc, f"SCALE5_R2_LANE_{lane}_OK", f"lane {lane} output")
        require(doc, f"work/groq-scale5-r2-0{lane}", f"lane {lane} isolated branch")

    request_ids = [
        "provider-request-1f436cff760d0df23fee049c70e3",
        "provider-request-cea2e9658819b7edce08f1464466",
        "provider-request-2791346cc14fed6ccc5963914809",
        "provider-request-72ba91b10f7c9be22d60d72ddc83",
        "provider-request-56d8f7e207ee49d91f9bde8031ac",
    ]
    receipts = [
        "provider-receipt-045147952388c4c4af667b48d247",
        "provider-receipt-71768cbd3247dc5e1b31818f1d1b",
        "provider-receipt-7522bc60a668519ff7e391bf470f",
        "provider-receipt-e4b8a2bd0b63962bd0474432e8b3",
        "provider-receipt-01404f8992920c240c716e4f20fa",
    ]
    for marker in request_ids + receipts:
        require(doc, marker, "runtime evidence")

    require(failover, "SCALE_5_SUCCEEDED", "failover status")
    require(failover, "SCALE_20 has not started", "scale-20 non-claim")
    require(failover, "GROQ_SCALE5_EVIDENCE.md", "evidence link")

    print("PASS: Groq REAL_EXTERNAL Scale-5 evidence is complete")


if __name__ == "__main__":
    main()
