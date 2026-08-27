# World 8 Engineering Fabric

Engineering Fabric is not a new canonical plane. It extends DCP and existing registries to make development resumable, multi-model, concurrent and evidence-driven.

Current foundation concepts:
- Persistent Actor + transient Execution Identity
- Architecture Realization Map
- Objective / Work DAG / Work Capsule
- Lease + TTL + Heartbeat + Fencing + CAS
- Code Shadow
- Diagnostic Memory
- Targeted Dispatch and breaking-change propagation
- WATCH-only Observer intake with dedupe/rate limiting
- Qualification primitives separated from Authorization

Not yet complete at bootstrap:
- Academy runtime admission pipeline
- Authorization integration into Preflight/Work Claim
- scoped credential broker
- canonical Git activation + CI/PR/merge queue
- isolated workspaces
- external observer pollers
