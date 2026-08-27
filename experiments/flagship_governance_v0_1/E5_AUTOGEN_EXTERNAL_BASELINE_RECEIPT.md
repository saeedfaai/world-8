# W8-P01 — E5 AutoGen Core External Baseline Receipt

Date: 2026-08-27
Status: **PASS / BOUNDED EXTERNAL-RUNTIME EVIDENCE**

## Execution

Because the private `world-8` GitHub-hosted runner failed before runner allocation (`runner_id=0`, no steps), the standalone benchmark was executed on the public publication bridge with no secrets or private World 8 data.

Successful run:
- repository: `saeedfaai/World-v6-public`
- branch: `w8-p01-autogen-baseline-run`
- source commit: `ba9fe95cc41b02bd04962d6e38b1b6afdeefe26a`
- GitHub Actions: https://github.com/saeedfaai/World-v6-public/actions/runs/33109497608
- job conclusion: SUCCESS
- pinned external runtime: `autogen-core==0.7.5`
- Python: `3.12.14`
- LLM used: false
- external provider/business effect: false
- trials per scenario/variant: 100
- scenarios: 10
- variants: 2
- total deterministic runtime cases: 2,000

Artifact:
- name: `w8-p01-autogen-public-baseline-v1.1`
- artifact id: `9661893952`
- artifact digest: `sha256:bb9ed255bc9b73ef359d452189c9bf1f629b67262137a05bbf930926837205b2`

Evidence hashes:
- `summary.json`: `7a2a84bdc385caf708b0e5e87e6c41a8761163900b0266c825ccc016eb2d15e7`
- `trials.jsonl`: `f0f4cd3c2478e9c2cbc5247e374b2a412899b520f26220a878d3f78146984f1c`
- `PIP_FREEZE.txt`: `07643dc6d4b7ff262a7e18e000ca97ded579bd76f600a14549f59d9a58444990`
- `PYTHON_VERSION.txt`: `4c3569f5da09975434dd9fd9a91fadbc4367a91d8f3c3fab59e9241ab9ee4bd8`

## Baseline definition

### `hardened`
Uses real AutoGen Core `SingleThreadedAgentRuntime`, `AgentId`, `RoutedAgent`, and direct message request/response.

Application-level generic hardening intentionally supplied:
- explicit approval token scoped to action/object;
- revoke-at-effect-time;
- CAS/version check;
- durable idempotency key;
- mutable durable audit log.

Not supplied in this variant:
- persistent logical Actor binding independent of AutoGen runtime `AgentId`;
- actor-bound approval;
- fencing generation/token;
- cryptographically chained governance receipts;
- recovery gate before effect capability resumes.

### `full`
Runs on the same AutoGen Core runtime and adds exactly those four governance groups as an explicit wrapper/augmented variant.

## Results

### Valid paths

| Scenario | Hardened safe/success | Hardened actor continuity | Full safe/success | Full actor continuity | Full false deny |
|---|---:|---:|---:|---:|---:|
| V1 normal | 1.0 | 1.0 | 1.0 | 1.0 | 0.0 |
| V2 runtime-key swap, same logical actor | 1.0 | 0.0 | 1.0 | 1.0 | 0.0 |
| V3 true AutoGen runtime recreation + recovery | 1.0 | 1.0* | 1.0 | 1.0 | 0.0 |

`*` Hardened V3 “actor continuity” is not asserted as persistent domain identity; its measured safe path is effect correctness after runtime recreation. The explicit identity challenge is V2.

### Fault paths

| Fault | Hardened safe rate | Full safe rate | Interpretation |
|---|---:|---:|---|
| X1 stolen approval after runtime identity swap | 0.0 | 1.0 | actor-bound approval closes tested gap |
| X2 explicit revocation before effect | 1.0 | 1.0 | generic hardening is sufficient; not a unique World 8 contribution |
| X3 stale version | 1.0 | 1.0 | CAS is generic; not a unique World 8 contribution |
| X4 duplicate retry | 1.0 | 1.0 | idempotency is generic; not a unique World 8 contribution |
| X5 stale fence after token rotation | 0.0 | 1.0 | explicit fencing closes tested gap |
| X6 post-effect audit tamper | 0.0 | 1.0 | hash-chain verification closes tested gap |
| X7 effect attempt after true runtime recreation but before recovery | 0.0 | 1.0 | recovery gate closes tested gap |

All rates are from 100 deterministic cases per scenario/variant with the frozen seed `20260827`.

## Strongest defensible interpretation

The experiment does **not** show that World 8 is generally superior to AutoGen Core.

It shows that:
1. a real AutoGen Core runtime can host the tested governance controls as application-level composition;
2. generic controls such as revocation, CAS, and durable idempotency remove several differences already seen against the internal hardened baseline;
3. in the frozen configurations, four additional governance groups — persistent actor-bound authority, fencing, tamper-evident receipts, and recovery-before-effect — close four specifically tested failure families;
4. the augmented AutoGen variant reaches the same tested safety outcomes, so the result supports **composability of the World 8 governance kernel**, not framework exclusivity.

## Claim ceiling

Allowed:
- “The tested governance controls can be composed over AutoGen Core 0.7.5 and close the four frozen fault families without false denials on the tested valid paths.”
- “Generic revoke/CAS/idempotency controls were sufficient for their corresponding fault families and are not treated as unique contributions.”

Not allowed:
- “World 8 beats AutoGen.”
- “AutoGen is insecure.”
- “AutoGen cannot implement these controls.”
- “World 8 is production-safe.”
- any arbitrary-fault or general distributed-systems superiority claim.

## Failed runs retained

Private runner allocation failure:
- `saeedfaai/world-8` run `33108873484`, attempts 1 and 2: `runner_id=0`, `steps=[]`; benchmark code did not execute.

Public benchmark first attempt:
- run `33109388339`: AutoGen installed successfully, then fixture failed before trials because `@message_handler` requires the handler parameter to be named `message`; source used `msg`.
- corrected in public source commit `ba9fe95cc41b02bd04962d6e38b1b6afdeefe26a`.

These failures are process/API diagnostics, not negative benchmark results.
