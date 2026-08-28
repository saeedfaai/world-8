from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

contract = (ROOT / 'architecture/contracts/guardian-operational-v0.1.yaml').read_text()
contract_v011 = (ROOT / 'architecture/contracts/guardian-operational-v0.1.1.yaml').read_text()
contract_v012 = (ROOT / 'architecture/contracts/guardian-operational-v0.1.2.yaml').read_text()
adr = (ROOT / 'architecture/adr/ADR-0003-operational-guardian-boundary.md').read_text()
dcr = (ROOT / 'architecture/proposals/DCR-0001-operational-guardian-dispatch-idempotency.md').read_text()
dcr2 = (ROOT / 'architecture/proposals/DCR-0002-operational-guardian-budget-scope-identity.md').read_text()
state = (ROOT / 'docs/engineering/guardian-operational/STATE_MACHINES_v0.1.md').read_text()
state_v011 = (ROOT / 'docs/engineering/guardian-operational/STATE_MACHINES_v0.1.1.md').read_text()
writer = (ROOT / 'docs/engineering/guardian-operational/WRITER_MATRIX_v0.1.md').read_text()
schema = (ROOT / 'docs/engineering/guardian-operational/schema/operational_guardian_schema_candidate_v0.1.sql').read_text()
schema_v011 = (ROOT / 'docs/engineering/guardian-operational/schema/operational_guardian_schema_candidate_v0.1.1.sql').read_text()
schema_v012 = (ROOT / 'docs/engineering/guardian-operational/schema/operational_guardian_schema_candidate_v0.1.2.sql').read_text()
negative = (ROOT / 'tests/guardian_operational/NEGATIVE_TEST_MATRIX_v0.1.md').read_text()
negative_v011 = (ROOT / 'tests/guardian_operational/NEGATIVE_TEST_DELTA_v0.1.1.md').read_text()
negative_v012 = (ROOT / 'tests/guardian_operational/NEGATIVE_TEST_DELTA_v0.1.2.md').read_text()
engineering_guardian = (ROOT / 'docs/engineering/ENGINEERING_GUARDIAN.md').read_text()
n_mason = (ROOT / 'docs/engineering/N_MASON_POOL.md').read_text()
worklog = (ROOT / 'docs/engineering/diagnostics/GUARDIAN_CONTRACT_V0_1_WORKLOG.md').read_text()

checks = {
    # Base trust/authority boundaries.
    'design frozen not implemented': all(x in contract for x in (
        'status: DESIGN_FROZEN',
        'implementation_status: NOT_IMPLEMENTED',
        'evidence_status: NOT_EVIDENCED',
        'deployment_status: NOT_DEPLOYED',
    )),
    'not plane six': 'guardian_is_plane_six: false' in contract,
    'observer guardian separation': 'observer: WHAT_HAPPENED' in contract and 'guardian_kernel: WHAT_MAY_RUN' in contract,
    'guardian cannot create or resolve gap': 'guardian_may_create_gap: false' in contract and 'guardian_may_close_gap: false' in contract,
    'guardian cannot evaluate or promote': 'guardian_may_evaluate_candidate_quality: false' in contract and 'guardian_may_promote_candidate: false' in contract,
    'guardian cannot hard revoke': 'guardian_may_hard_revoke_authority: false' in contract,
    'effect allowance not authorization': 'allowance_is_authorization: false' in contract,
    'advisor optional': 'required_for_dispatch: false' in contract and 'advisor_absence_behavior: KERNEL_CONTINUES_WITH_DETERMINISTIC_POLICY' in contract,
    'partitioned ledger no global head': 'model: PARTITIONED_APPEND_ONLY_EVENT_SOURCING' in contract and 'global_head: false' in contract,
    'no cross ledger 2pc': 'distributed_2pc: forbidden' in contract and 'cross_ledger_linearizability_claim: forbidden' in contract,
    'epoch fencing every write': 'every_control_write_fenced_by_epoch: true' in contract,
    'child envelopes': 'hierarchical_model: PREFUNDED_CHILD_ENVELOPES' in contract,
    'budget accounting invariant': 'invariant: S + R + A = C + O' in contract,
    'sharded redundant forbidden': 'SHARDED_X_REDUNDANT_N_FORBIDDEN' in contract,
    'observer compatibility classes': all(x in contract for x in ('STRICTER', 'RELAXED', 'BREAKING')),
    'society isolation': 'cross_society_borrowing: forbidden' in contract and 'cross_society_quarantine_query: forbidden' in contract,
    'existing engineering guardian stays authority none': 'authority_effect=NONE' in engineering_guardian,
    'existing n mason identity provider independent': 'Provider belongs to Execution, not Actor' in n_mason,

    # Reuse / physical-boundary checks.
    'schema extends existing mason assignment': 'references public.world8_mason_assignments(assignment_id)' in schema,
    'schema does not create actor registry': 'NO new Actor registry.' in schema,
    'schema does not create mutable gap': 'NO mutable GapSignal table/status.' in schema,
    'capacity lease explicitly no write authority': 'Never grants developer/canonical write authority' in schema,
    'control events append only': 'WORLD8_OPERATIONAL_GUARDIAN_CONTROL_EVENTS_APPEND_ONLY' in schema,
    'advisory append only': 'WORLD8_OPERATIONAL_GUARDIAN_ADVISORY_APPEND_ONLY' in schema,
    'writer matrix guardian no promotion': '| Promote/activate accepted Candidate | NO | NO | NO | NO | NO | AUTHORIZE | YES |' in writer,
    'writer matrix guardian no hard revoke': '| HARD_REVOKE RoleBinding/credential/ceiling | NO | NO | NO | NO | NO | YES | YES |' in writer,
    'state machine provider deadline immutable': 'Provider switch never resets Deadline budget.' in state,
    'state machine gap completion separation': 'Work completion does not imply Gap resolution.' in state,

    # Base test specification only; still no runtime evidence.
    'negative test coverage >= 50 ids': sum(1 for line in negative.splitlines() if line.startswith('| OG-N')) >= 50,
    'mutation families present': 'Required mutation families' in negative,
    'no pass claim in base test spec': 'NO RUNTIME PASS CLAIM' in negative,

    # DCR-0001 reconciliation visible in base working-copy artifacts.
    'dcr0001 accepted': 'Status: ACCEPTED FOR v0.1 ARTIFACT RECONCILIATION' in dcr,
    'contract cites dcr0001': 'DCR-0001-operational-guardian-dispatch-idempotency' in contract,
    'contract dispatch slot key required': 'dispatch_slot_key' in contract and '- dispatch_slot_key' in contract,
    'contract natural key uses dispatch slot': all(x in contract for x in ('- gap_id', '- policy_version', '- dispatch_slot_key', '- attempt_no')),
    'state natural key uses dispatch slot': '(gap_id, policy_version, dispatch_slot_key, attempt_no)' in state,
    'schema has dispatch slot field': 'dispatch_slot_key text not null' in schema,
    'schema unique key uses dispatch slot': 'unique(gap_id,policy_version,dispatch_slot_key,attempt_no)' in schema,
    'schema enforces dispatch slot families': all(x in schema for x in ("dispatch_slot_key='single'", "dispatch_slot_key like 'redundant:%'", "dispatch_slot_key like 'shard:%'")),
    'work lifecycle does not encode quarantine': "'EXPIRED','QUARANTINED'" not in schema and 'QUARANTINED` is not a second WorkAssignment truth state' in state,

    # v0.1.1 explicit corrective marker.
    'v011 frozen not implemented': all(x in contract_v011 for x in (
        "version: '0.1.1'",
        'status: DESIGN_FROZEN',
        'implementation_status: NOT_IMPLEMENTED',
        'evidence_status: NOT_EVIDENCED',
        'deployment_status: NOT_DEPLOYED',
        'effective_for_implementation: true',
    )),
    'v011 references base and dcr': 'base_contract: architecture/contracts/guardian-operational-v0.1.yaml' in contract_v011 and 'DCR-0001-operational-guardian-dispatch-idempotency.md' in contract_v011,
    'v011 trust authority boundary unchanged': 'trust_boundary_changed: false' in contract_v011 and 'authority_boundary_changed: false' in contract_v011,
    'v011 records base working-copy reconciliation': 'reconciled_in_base_working_copy: true' in contract_v011,
    'v011 dispatch slot immutable deterministic': 'required_field: dispatch_slot_key' in contract_v011 and 'immutable: true' in contract_v011 and 'deterministic: true' in contract_v011,
    'v011 assignment kind not slot identity': 'assignment_kind_is_unique_slot_identity: false' in contract_v011,
    'v011 quarantine overlay': 'quarantined_is_core_work_state: false' in contract_v011 and 'SEPARATE_QUARANTINE_DECISION_AGGREGATE' in contract_v011,
    'v011 read order explicit': 'implementation_read_order:' in contract_v011 and 'NEGATIVE_TEST_DELTA_v0.1.1.md' in contract_v011,
    'v011 state uses effective natural key': '(gap_id, policy_version, dispatch_slot_key, attempt_no)' in state_v011,
    'v011 state defines slot forms': all(x in state_v011 for x in ('`single`', '`redundant:<ordinal>`', '`shard:<work_order_id>`')),
    'v011 schema overlay requires slot': 'dispatch_slot_key text not null' in schema_v011,
    'v011 schema overlay requires corrected unique tuple': 'unique(gap_id, policy_version, dispatch_slot_key, attempt_no)' in schema_v011,
    'v011 schema overlay forbids quarantine core state': 'Forbidden future physical model:' in schema_v011 and "state IN (..., 'QUARANTINED')" in schema_v011,
    'v011 test delta complete': all(f'| OG-N{i} |' in negative_v011 for i in range(51, 64)),
    'v011 tests valid redundant lanes': 'redundant:1' in negative_v011 and 'redundant:2' in negative_v011,
    'v011 tests immutable slot': 'immutable identity field' in negative_v011,
    'v011 tests quarantine overlay': 'WorkControl core state is set to `QUARANTINED`' in negative_v011,
    'v011 no runtime pass claim': 'NO RUNTIME PASS CLAIM' in negative_v011,

    # DCR-0002 / v0.1.2 budget-scope identity repair.
    'dcr0002 accepted': 'Status: ACCEPTED FOR v0.1 FAMILY ARTIFACT RECONCILIATION' in dcr2,
    'dcr0002 identifies null unique risk': 'ordinary UNIQUE semantics treat NULL values as distinct' in dcr2,
    'v012 frozen not implemented': all(x in contract_v012 for x in (
        "version: '0.1.2'",
        'status: DESIGN_FROZEN',
        'implementation_status: NOT_IMPLEMENTED',
        'evidence_status: NOT_EVIDENCED',
        'deployment_status: NOT_DEPLOYED',
        'effective_for_implementation: true',
    )),
    'v012 references previous and dcr2': 'previous_effective_revision: architecture/contracts/guardian-operational-v0.1.1.yaml' in contract_v012 and 'DCR-0002-operational-guardian-budget-scope-identity.md' in contract_v012,
    'v012 trust authority unchanged': 'trust_boundary_changed: false' in contract_v012 and 'authority_boundary_changed: false' in contract_v012,
    'v012 canonical scope identity': all(x in contract_v012 for x in ('- society_id', '- scope_kind', '- scope_ref', '- dimension_class', '- dimension_key')),
    'v012 nullable tuple forbidden': 'nullable_project_pool_tuple_as_unique_identity: forbidden' in contract_v012,
    'v012 same society requirements': 'parent_child_same_society_required: true' in contract_v012 and 'reservation_assignment_society_match_required: true' in contract_v012,
    'v012 preserves accounting invariant': 'accounting: S + R + A = C + O' in contract_v012,
    'v012 schema overlay requires nonnull scope': all(x in schema_v012 for x in ('scope_kind text not null', 'scope_ref text not null', 'length(trim(scope_ref)) > 0')),
    'v012 schema overlay requires null safe identity': 'UNIQUE(society_id, scope_kind, scope_ref, dimension_class, dimension_key)' in schema_v012,
    'v012 schema overlay forbids nullable identity': 'Forbidden future physical identity:' in schema_v012,
    'v012 test delta complete': all(f'| OG-N{i} |' in negative_v012 for i in range(64, 74)),
    'v012 tests cross society hierarchy': 'Parent envelope Society A allocates child envelope in Society B' in negative_v012,
    'v012 tests concurrent identity race': 'Two concurrent creates race' in negative_v012,
    'v012 no runtime pass claim': 'NO RUNTIME PASS CLAIM' in negative_v012,
    'worklog effective baseline records v012': 'v0.1.2` is the effective corrective revision for implementation' in worklog,
    'worklog records budget null identity diagnostic': 'BUDGET_SCOPE_NULL_UNIQUENESS_RISK' in worklog,

    # Historical diagnostic retained.
    'worklog records freeze reconciliation diagnostic': 'FROZEN_ARTIFACT_RECONCILED_IN_PLACE_RISK' in worklog,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('Operational Guardian contract validation failed: ' + ', '.join(failed))

print(
    'Operational Guardian static contract validation PASS:',
    len(checks),
    'checks; effective_revision=v0.1.2; evidence ceiling=STATIC_DESIGN_CONFORMANCE_ONLY; runtime evidence=NONE',
)
