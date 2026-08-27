# World 8 Groq REAL_EXTERNAL Scale-5 Evidence

Status: `SCALE_5_SUCCEEDED / 5_OF_5_SUCCESS / ZERO_FAILURE / CLEAN_RELEASE / SCALE_20_ELIGIBLE_NOT_STARTED`

Date: 2026-08-27
Canonical base: `a46bab811965434ff4f491f30953292de8d7e41b`
Provider: `Groq`
Model: `openai/gpt-oss-20b`
Adapter: `adapter-groq-external-v01`
Credential binding: `binding-groq-envref-key4-v01` / `envref:GROQ_API_KEY4`
Transport: `transport-supabase-groq-generic-v01`

## Gate before execution

- Provider Failover Mesh v0.1 was merged to main in PR #29.
- CI run `33106176872` passed.
- DCP canonical Git resource was synchronized to merge `a46bab811965434ff4f491f30953292de8d7e41b` before the second scale reservation.
- Groq readiness was `PASS / LIVE_READY`.
- Groq provider health was not hard-blocked.
- Five fresh Mason assignments, five fresh Work claims, and five isolated Git workspaces were created.
- Every lane had `max_real_executions=1` and no canonical mutation plan.
- `automatic_retry=false` remained in force.

An initial five-assignment reservation was safely released before execution because the DCP canonical-head projection still pointed to the pre-PR29 commit. No provider request was created from those stale reservations.

## Runtime results

| Lane | Actor | Assignment | Work | Workspace | Request | Execution | Success receipt | Output | SHA-256 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `mason-worker-7dedb0-0001` | `assignment-fedc6bb066fadeee7f114dcf7293657c` | `work-a890ec6581c4fb945412a8c7082b` | `workspace-17b2f6fa6b8ee36dc496432c2c9a9f83` | `provider-request-1f436cff760d0df23fee049c70e3` | `execution-cb4cb09187e94304210ef6fb68f66b6a` | `provider-receipt-045147952388c4c4af667b48d247` | `SCALE5_R2_LANE_1_OK` | `303964073d726155ea790b1ca197b9af9f9a4e4cd679c7cd85d9654412d21d2e` |
| 2 | `mason-worker-7dedb0-0002` | `assignment-f251303f16539fa1a4cd61c70de0489d` | `work-2a57213f989af9f31404a67699dd` | `workspace-9e6918d53b2d1d036b589f882681304b` | `provider-request-cea2e9658819b7edce08f1464466` | `execution-c991b22f841e528bf6b0fa70188462fc` | `provider-receipt-71768cbd3247dc5e1b31818f1d1b` | `SCALE5_R2_LANE_2_OK` | `9421c26cafde6ddfa10b04b8062e19bf53863d11290ea7cfc4f2373e95d40086` |
| 3 | `mason-worker-7dedb0-0003` | `assignment-0807154c798c6476ac5be94dd43d39d5` | `work-8c0c3e8f03a44fee64fe40f7eef3` | `workspace-2f74379d26dc794bbe7ebfb842ff604d` | `provider-request-2791346cc14fed6ccc5963914809` | `execution-50677437b0aadac62fa399e85798106b` | `provider-receipt-7522bc60a668519ff7e391bf470f` | `SCALE5_R2_LANE_3_OK` | `ae45a3e62adf41a81dd01796ef45af8f72f246b32cf6279264ee3176433ae0d8` |
| 4 | `mason-worker-7dedb0-0004` | `assignment-6b3e9ba0c1f41c785c915062c2671109` | `work-6e1da341dd26239507e451532191` | `workspace-6348a40253c6792d30af3f32cc8a68b2` | `provider-request-72ba91b10f7c9be22d60d72ddc83` | `execution-499a0cec0fbaded2c37d9575c749693e` | `provider-receipt-e4b8a2bd0b63962bd0474432e8b3` | `SCALE5_R2_LANE_4_OK` | `2cb91a59e60748ea9c76ed07ca7a11f2b494fec99dac9bbacb873ed908383e03` |
| 5 | `mason-worker-7dedb0-0005` | `assignment-74fb6b83a38c1f3aceceae5173e3abfa` | `work-46bae063e66f91bb494ff4386aa4` | `workspace-0d7b5e986761a2045735c850529d81b5` | `provider-request-56d8f7e207ee49d91f9bde8031ac` | `execution-f988b8b24b54cc99722392848f23751a` | `provider-receipt-01404f8992920c240c716e4f20fa` | `SCALE5_R2_LANE_5_OK` | `55ffe4716eeed973a5cbc4f2cccebe2846b009c612e5e8f5d5cac9328a6d7d67` |

All five lanes recorded:

- request state `SUCCEEDED`;
- provider HTTP status `200`;
- `live_provider_invoked=true`;
- `test_only=false`;
- one append-only output reference;
- one provider request-id evidence reference;
- raw secret stored: false;
- private reasoning stored: false.

Each output was exactly 19 bytes and matched its lane marker. No lane required retry or failover to another provider.

## Cleanup and health

All five Workspaces were released after evidence recording.
All five Mason Assignments were released after evidence recording.

Groq health was projected as:

- `HEALTHY`
- reason: `SCALE5_SUCCEEDED`
- receipt: `provider-health-34c974ca47a12e5822558d94e698`
- successful lanes: 5
- failed lanes: 0

## Scale decision

This evidence satisfies the formal five-execution stage. It does not prove 20 or 100 real provider executions.

The next eligible stage is 20 real executions, but it must not start automatically. Before stage 20, re-check canonical head, provider readiness, provider health, current rate/cost constraints, and resource cleanup. Create fresh governed execution budgets; do not reuse these five Work items.

## Non-negotiable boundaries

- Do not expose `GROQ_API_KEY4` raw value.
- Do not convert provider identity into Actor identity.
- Do not enable automatic retry in v0.1.
- Do not count prior orchestration-only 100-Mason tests as live provider scale evidence.
- Do not claim SCALE_20 or SCALE_100 until those stages have their own runtime receipts.