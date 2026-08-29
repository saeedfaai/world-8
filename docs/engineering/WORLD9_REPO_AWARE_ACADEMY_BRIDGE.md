# World 9 Repo-Aware Academy Bridge — World 8 v0.5

Status: **PROPOSAL ONLY / NOT APPLIED / NOT DEPLOYED**

## Why this bridge exists

World 8 engineering governance currently treats one Git repository as canonical through `resource-github-world8-canonical`. The live Workspace v1, Academy Entry v1 and Admission v2 path therefore cannot truthfully admit a WRITE workspace in `saeedfaai/world-9-runtime` even when the World 9 branch itself is correctly isolated.

The v0.5 bridge makes canonical Git identity **resource-aware** without making repository identity caller-controlled. The caller does not get to declare a repository canonical. It must supply the ID of an already ACTIVE `world8_dev_external_resources` row that has `resource_type=GITHUB`, `metadata.canonical=true`, the canonical architecture/code role, a GitHub `provider_ref`, a current 40-hex canonical head, and a default branch.

No World 9 resource row is inserted by this proposal. Enrollment is a later, separately governed action.

## Additive design

The existing World8-only v1/v0.4 path stays intact. The proposal adds:

- `world8_dev_workspace_git_bindings` — append-only evidence binding one Workspace to one exact canonical resource and observed head.
- `world8_academy_entry_git_bindings` — append-only evidence binding one Academy Entry to the same resource/head.
- `world8_dev_canonical_git_resource_current_v1` — internal fail-closed validator for enrolled canonical Git resources.
- `world8_dev_register_workspace_v2` — repo-aware Workspace registration.
- `world8_academy_coding_entry_issue_v2` — repo-aware Academy Entry with `authority_effect=NONE`.
- `world8_dev_admission_check_v4` — repo-aware Admission that preserves the existing qualification and Authority Fabric semantics.

`world8_dev_record_prewrite_recovery_v1` and `world8_dev_acquire_lease_v5` remain shared. Their binding is Workspace/Entry/Admission/Recovery/Artifact based and they do not hard-code a repository.

## Fail-closed rules

A canonical resource is evidence, not a string convention. Resource lookup must succeed and the active row must describe a canonical GitHub repository. `repo_ref` must exactly match the repository portion of `provider_ref`. The Workspace base must exactly match the current enrolled `canonical_head_commit`. A WRITE branch may not be `main`, `master`, or the resource's own default branch.

Workspace and Entry bindings are append-only. If the resource's canonical head moves after a Workspace or Entry was created, Admission v4 rejects the stale evidence instead of silently re-basing it. A new Workspace/Entry must be produced from the new head.

Entry continues to grant **zero authority**. Admission v4 still calls the existing `world8_dev_assignment_check_v1` for qualification and `world8_authorize_v1` for authorization. When authorization is requested, its scope is strengthened with exact `work_id`, `execution_id`, `workspace_id`, `canonical_resource_id`, `repo_ref`, `branch_ref`, and `canonical_head`.

## World 9 activation sequence

After this candidate is independently reviewed and integrated into World 8 under a short HumanRoot-scoped branch CODE_WRITE rule, it can be tested on PostgreSQL 17 inside an explicit transaction and rolled back. Persistent installation is a separate governed DB-touching action.

Only after installation may World 8 separately enroll a resource such as:

- resource: `resource-github-world9-runtime-canonical`
- provider: `github:saeedfaai/world-9-runtime`
- default branch / parent integration branch metadata
- exact current canonical head

That enrollment must itself be auditable and cannot be smuggled into this migration.

Once enrolled, a World 9 Integrator can use the real path:

`Workspace v2 → Academy Entry v2 → Admission v4 → Prewrite Recovery → Lease v5 → exact reviewed patch import → tests → Handoff/Postflight`

Proposal contractors remain proposal-only and cannot use this bridge to acquire canonical authority.

## Security and nonclaims

This proposal creates no passwords, API keys, provider credentials, Authority Tokens, Principals or external effects. It does not authorize runtime DDL by existing merely as code. It does not modify `main`, does not replace v1/v0.4 behavior, and does not claim World 9 is already canonical.

Continuity remains separately governed and remains disabled wherever its external dual-partition obligation is still open.
