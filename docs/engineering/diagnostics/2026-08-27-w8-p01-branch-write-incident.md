# Diagnostic Memory — W8-P01 accidental direct write to main

Date: 2026-08-27
Status: RESOLVED / EXPERIENCE_CAPTURED
Scope: W8-P01 flagship experiment startup

## Incident

While starting `work/w8-p01-governance-experiment-v0.1`, an attempted write to a not-yet-created branch failed with HTTP 404. During recovery, a temporary file containing only `TEMP` was mistakenly created directly on `main` at:

`experiments/flagship_governance_v0_1/PROTOCOL.md`

This violated the World 8 governed-development rule that normal work must occur on an isolated branch/workspace rather than directly on `main`.

## Containment

- No production/runtime code or provider secret was changed.
- The temporary file contained no substantive experiment content.
- The file was immediately removed from `main` in follow-up commit `b205c14b033749bfd0eeabfddb1df1957caa6be6`.
- The dedicated branch `work/w8-p01-governance-experiment-v0.1` was then created before substantive writes resumed.

## Root cause

Recovery from the missing-branch error used the wrong fallback action: creating a placeholder on `main` instead of first creating the branch.

## Derived rule

When a branch-scoped write returns `Branch not found`, the only safe recovery sequence is:

1. verify current canonical head;
2. create the intended branch from that head;
3. retry the write on that branch;
4. never use `main` as a placeholder/staging target.

## Evidence

- Accidental create commit: `5d6cb7459fe62b2ac0bec2c14ba313cf827e0091`
- Cleanup commit: `b205c14b033749bfd0eeabfddb1df1957caa6be6`
- Correct experiment branch: `work/w8-p01-governance-experiment-v0.1`

The incident is retained because repaired errors remain part of World 8 Diagnostic Memory.
