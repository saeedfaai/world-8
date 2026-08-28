# Operational Guardian v0.1 — Writer / Authority Matrix

Status: DESIGN FROZEN / IMPLEMENTATION NOT STARTED

This matrix is normative. A runtime implementation that grants a broader writer than this matrix is non-conformant.

| Object / Action | Observer | Guardian Kernel | Mason / Planner | Integrator Mason | Evaluator | Governance / Human Root | Spine / Governed Commit |
|---|---:|---:|---:|---:|---:|---:|---:|
| Emit immutable GapSignal | YES | NO | NO | NO | NO | HUMAN-MEASURED GAP ONLY | NO |
| Emit measurement GapLifecycleEvent | YES | NO | NO | NO | NO | Contract succession metadata only | NO |
| Create/extend existing Mason pool assignment binding | NO | YES, through existing N-Mason contracts | NO | NO | NO | MAY GOVERN POLICY | NO |
| Create Operational WorkControl extension | NO | YES | NO | NO | NO | NO | NO |
| Propose decomposition plan | NO | NO | YES | YES if acting as planner under separate proposal | NO | MAY REQUEST | NO |
| Validate decomposition against deterministic policy | NO | YES | NO | NO | NO | policy source only | NO |
| Create Candidate | NO | NO | YES | YES | NO | NO | NO |
| Evaluate Candidate quality | NO | NO | NO | NO | YES | MAY REVIEW EVIDENCE | NO |
| Create SelectionDecision | NO | NO | NO | NO | MAY SUPPLY RANKING EVIDENCE | YES | NO |
| Promote/activate accepted Candidate | NO | NO | NO | NO | NO | AUTHORIZE | YES |
| Allocate within pre-funded child envelope | NO | YES | request only | request only | request capacity only | MAY OVERRIDE BY GOVERNED POLICY | NO |
| Increase child/project/society hard ceiling | NO | NO | NO | NO | NO | YES | RECORDS CANONICAL DECISION |
| Create/settle BudgetReservation within envelope | NO | YES | request/use only | request/use only | request/use only | MAY GOVERN POLICY | NO |
| Acquire Guardian capacity/semantic lease | NO | YES | consume bound lease only | consume bound lease only | consume bound lease only | MAY GOVERN POLICY | NO |
| Grant developer/canonical write authority | NO | NO | NO | NO | NO | authority path only | governed authority/lease system |
| Emit AdvisoryReceipt | NO | MAY RECORD receipt | MAY PRODUCE advisory proposal if assigned role | MAY PRODUCE advisory proposal if assigned role | NO | NO | NO |
| Apply SOFT_QUARANTINE | NO | YES, deterministic policy only | NO | NO | NO | MAY LIFT/OVERRIDE VIA GOVERNED PATH | NO |
| HARD_REVOKE RoleBinding/credential/ceiling | NO | NO | NO | NO | NO | YES | YES |
| Suppress telemetry / Detector / Gap mint | NO | NO | NO | NO | NO | only through explicit governed Observation contract change | NO |
| Authorize external business effect | NO | NO | NO | NO | NO | governed effect policy | governed effect path |
| Allocate external-effect allowance capacity | NO | YES | request only | request only | request only | MAY GOVERN CEILING | NO |
| Change Guardian policy version | NO | NO | proposal only through normal change path | proposal only | evaluate change evidence only | YES | YES |
| Append Operational control transition | NO | YES through fenced RPC | NO direct SQL | NO direct SQL | NO direct SQL | only governed exceptional actions where contract allows | NO |
| Modify/delete committed Operational event | NO | NO | NO | NO | NO | NO | NO |

## Important distinctions

### Existing Engineering Guardian

`service-world8-engineering-guardian` remains an advisory/context service with `authority_effect=NONE`. It is not automatically the writer principal for the Operational Guardian tables.

### Existing N-Mason truth

`world8_mason_assignments` remains assignment identity/binding truth. `world8_guardian_work_controls` is only a one-to-one orchestration extension and MUST NOT mint independent worker identity.

### Existing developer lease truth

`world8_dev_leases` remains the authority-bearing governed developer write lease. `world8_guardian_capacity_leases` only reserves capacity or semantic resources and MUST NOT be accepted as code/canonical write authorization.

### Advisor

Advisor output is optional and non-authoritative. Advisor absence is a valid operating state. Advisor output cannot define a new failure class, hard ceiling, authority grant, quarantine lift, Promotion or effect authorization.

## Default privilege stance

Until live role inventory is resolved through the governed runtime path:

- no direct `anon` mutation;
- no direct `authenticated` mutation;
- no direct Brain/Mason SQL mutation;
- mutation through narrow SECURITY DEFINER RPCs only after exact role review;
- service-role breadth is not itself accepted as application authority;
- every mutation RPC must re-check policy version, Society scope, epoch/fencing, CAS/idempotency and transition legality at commit time.
