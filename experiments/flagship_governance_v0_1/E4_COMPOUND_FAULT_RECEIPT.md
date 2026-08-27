# W8-P01 — E4 Compound-Fault Gate Receipt

Date: 2026-08-27
Status: **PASS / REFERENCE-MODEL COMPOUND-FAULT EVIDENCE**

## Run

- GitHub Actions: https://github.com/saeedfaai/world-8/actions/runs/33108000278
- artifact: `w8-p01-compound-fault-gate-v1`
- artifact digest: `sha256:94817f523a294192b0805b90a456c55af6903ed76d01f101c49bf13f284bb161`
- `compound_fault_gate_v1.json` SHA256: `79341467909930b09460082f34402686e2fb7f0de6df46ed4bf30fb816d94e1d`
- seed: `20260827`
- trials per case: `1000`
- runtime DB mutated: `false`

## Results

| Case | World 8 safe rate | Hardened baseline failure exposed |
|---|---:|---:|
| CF1 stolen authorization after identity swap | 1.0 | 1.0 |
| CF2 stale fence after restart/rotation | 1.0 | 1.0 |
| CF3 restart then evidence tamper | 1.0 | 1.0 |

Valid-path controls:

| Valid path | World 8 success | World 8 false-deny rate |
|---|---:|---:|
| normal | 1.0 | 0.0 |
| session swap | 1.0 | 0.0 |
| restart/reconstruct | 1.0 | 0.0 |

## Interpretation

The reference model remains fail-closed under the three tested compound-fault schedules while preserving all tested valid paths. The hardened session-scoped baseline exposes the targeted failure in each corresponding compound case.

This result is **not** a claim of arbitrary distributed-systems correctness, production security, or general superiority over external agent frameworks. The compound gate is controlled reference-model evidence and must be read together with the runtime behavioral probes in E3/E4.
