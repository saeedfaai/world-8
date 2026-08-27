from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIG = ROOT / "supabase" / "migrations"
WORKER = ROOT / "supabase" / "functions" / "world8-provider-worker-generic-v01" / "index.ts"
DOC = ROOT / "docs" / "engineering" / "PROVIDER_FAILOVER_MESH.md"
WF = ROOT / ".github" / "workflows" / "validate-architecture.yml"


def require(text: str, marker: str, label: str) -> None:
    if marker not in text:
        raise SystemExit(f"FAIL: missing {label}: {marker}")


def main() -> None:
    sql_files = sorted(MIG.glob("*provider_failover*.sql")) + sorted(MIG.glob("*groq_credential_key4*.sql"))
    if not sql_files:
        raise SystemExit("FAIL: Provider Failover migrations missing")
    sql = "\n".join(p.read_text(encoding="utf-8") for p in sql_files)
    worker = WORKER.read_text(encoding="utf-8")
    doc = DOC.read_text(encoding="utf-8")
    wf = WF.read_text(encoding="utf-8")

    for marker in [
        "world8_provider_failover_policies",
        "PROVIDER_FAILOVER_POLICY_APPEND_ONLY",
        "FAILOVER_AUTOMATIC_RETRY_DISABLED_V01",
        "selection_is_advisory_only",
        "world8_provider_health_receipts",
        "PROVIDER_HEALTH_RECEIPTS_APPEND_ONLY",
        "ADMIN_BLOCKED",
        "PROVIDER_HEALTH_HARD_BLOCKED",
        "world8_provider_worker_route_context_v1",
        "world8_provider_credential_probe_context_v1",
        "adapter-groq-external-v01",
        "adapter-deepseek-external-v01",
        "adapter-openrouter-external-v01",
        "adapter-cerebras-external-v01",
        "adapter-mistral-external-v01",
        "binding-groq-envref-key4-v01",
        "envref:GROQ_API_KEY4",
        "envref:DEEPSEEK_API_KEY",
        "envref:OPENROUTER_API_KEY",
        "envref:CEREBRAS_API_KEY",
        "envref:MISTRAL_API_KEY",
        "provider-failover-code-assist-v01",
        "CODE_ASSIST_PRIMARY",
    ]:
        require(sql, marker, "SQL invariant")

    for marker in [
        'const WORKER_ID = "world8-provider-worker-generic-v01"',
        "world8_provider_execution_worker_claim_v1",
        "world8_provider_execution_output_record_v1",
        "world8_provider_execution_complete_v2",
        "world8_provider_credential_probe_attest_v1",
        "world8_provider_worker_challenge_attest_v1",
        "envref:",
        "provider_response_body_stored: false",
        "private_reasoning_present: false",
        "raw_secret_present: false",
    ]:
        require(worker, marker, "generic worker invariant")

    forbidden = ["sk-proj-", "BEGIN PRIVATE KEY", "chain_of_thought\""]
    corpus = sql + "\n" + worker + "\n" + doc
    for marker in forbidden:
        if marker in corpus:
            raise SystemExit(f"FAIL: forbidden secret/private-reasoning marker present: {marker}")

    require(doc, "automatic_retry=false", "documentation failover rule")
    require(doc, "ADMIN_BLOCKED / INSUFFICIENT_QUOTA", "documentation circuit breaker")
    require(doc, "envref:GROQ_API_KEY4", "documentation corrected Groq binding")
    require(doc, "GROQ_CANARY_SUCCEEDED", "documentation successful canary state")
    require(doc, "SCALE_5_ELIGIBLE_NOT_STARTED", "documentation next scale gate")
    require(wf, "python scripts/validate_provider_failover_mesh.py", "workflow validator step")

    print(f"PASS: Provider Failover Mesh invariants ({len(sql_files)} migration files)")


if __name__ == "__main__":
    main()
