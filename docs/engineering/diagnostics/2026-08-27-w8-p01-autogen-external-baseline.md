# Diagnostic — W8-P01 AutoGen External Baseline

Date: 2026-08-27
Status: RESOLVED / EVIDENCE PRESERVED

## Incident A — private GitHub runner not allocated

Context:
`saeedfaai/world-8` external AutoGen baseline workflow.

Run:
- `33108873484`
- attempt 1 job `98646037751`
- attempt 2 job `98646731806`

Observed:
- `runner_id=0`
- `runner_name=''`
- `steps=[]`
- conclusion `failure` within ~2 seconds

Interpretation:
The benchmark code never executed. This must not be classified as a benchmark/test failure.

Resolution:
Move the standalone, non-secret benchmark to public bridge `saeedfaai/World-v6-public`, preserving pinned dependency and machine-readable artifacts.

Rule derived:
**Distinguish infrastructure pre-start failure from experiment failure using runner/step receipts before interpreting a red workflow.**

## Incident B — AutoGen `message_handler` parameter-name contract

First public run:
- `33109388339`

Environment/setup:
- GitHub runner allocated successfully
- Python 3.12.14
- `autogen-core==0.7.5` installed successfully

Failure:
`AssertionError: message parameter not found in function signature`

Cause:
The fixture handler was declared:
`async def handle(self, msg: EffectRequest, ctx: MessageContext)`

AutoGen Core 0.7.5's `@message_handler` decorator inspects the function signature and expects the message parameter to be named `message`.

Repair:
Rename `msg` → `message` and use the renamed parameter in the handler body.

Repair commit on public bridge:
`ba9fe95cc41b02bd04962d6e38b1b6afdeefe26a`

Successful run:
`33109497608`

Rule derived:
**When integrating an external framework as an empirical baseline, pin the exact version and treat decorator/signature contracts as versioned API surface; preserve failed integration runs instead of silently rewriting the experiment.**

## Scientific handling

Neither incident changes the frozen comparison hypotheses or expected result gate.
No result was counted until the final successful run produced the artifact and passed the explicit bounded-result validator.
