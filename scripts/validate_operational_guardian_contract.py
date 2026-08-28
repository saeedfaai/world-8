from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
contract = (ROOT / 'architecture/contracts/guardian-operational-v0.1.yaml').read_text()
adr = (ROOT / 'architecture/adr/ADR-0003-operational-guardian-boundary.md').read_text()
state = (ROOT / 'docs/engineering/guardian-operational/STATE_MACHINES_v0.1.md').read_text()
writer = (ROOT / 'docs/engineering/guardian-operational/WRITER_MATRIX_v0.1.md').read_text()
schema = (ROOT / 'docs/engineering/guardian-operational/schema/operational_guardian_schema_candidate_v0.1.sql').read_text()
negative = (ROOT / 'tests/guardian_operational/NEGATIVE_TEST_MATRIX_v0.1.md').read_text()
engineering_guardian = (ROOT / 'docs/engineering/ENGINEERING_GUARDIAN.md').read_text()
n_mason = (ROOT / 'docs/engineering/N_MASON_POOL.md').read_text()

checks = {
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
    'sharded redundant forbidden v01': 'SHARDED_X_REDUNDANT_N_FORBIDDEN' in contract,
    'observer compatibility classes': all(x in contract for x in ('STRICTER', 'RELAXED', 'BREAKING')),
    'society isolation': 'cross_society_borrowing: forbidden' in contract and 'cross_society_quarantine_query: forbidden' in contract,
    'existing engineering guardian stays authority none': 'authority_effect=NONE' in engineering_guardian,
    'existing n mason identity provider independent': 'Provider belongs to Execution, not Actor' in n_mason,
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
    'negative test coverage >= 50 ids': sum(1 for line in negative.splitlines() if line.startswith('| OG-N')) >= 50,
    'mutation families present': 'Required mutation families' in negative,
    'no pass claim in test spec': 'NO RUNTIME PASS CLAIM' in negative,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('Operational Guardian contract validation failed: ' + ', '.join(failed))
print('Operational Guardian contract validation PASS:', len(checks), 'static checks')
