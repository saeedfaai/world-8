# World 8 — Hugging Face Phase 1

Priority: P1 / VERY HIGH
Status: PUBLISHED UNDER VERIFIED USER ACCOUNT
Completed: 2026-08-27

## Goal
Create the AI-native public surface for World 8 while keeping GitHub canonical.

## Verified account
- Username: `Saeedfa`
- Account: https://huggingface.co/Saeedfa
- Authenticated `whoami`: HTTP 200
- Token type: fine-grained
- Organization memberships at publication time: none

## Published structure
- World 8 Collection: https://huggingface.co/collections/Saeedfa/world-8-6a902b1a3a05b0ab39990265
- `world8-core`: https://huggingface.co/Saeedfa/world8-core
- `world8-forecast-hall`: https://huggingface.co/Saeedfa/world8-forecast-hall
- `world8-market-data`: https://huggingface.co/Saeedfa/world8-market-data
- public Static Space `world8-demo`: https://huggingface.co/spaces/Saeedfa/world8-demo

## Canonicality
Every Hugging Face surface points back to:
1. `https://github.com/saeedfaai/world-8`
2. development pre-release `https://github.com/saeedfaai/world-8/releases/tag/V0.1.0`
3. the current World 8 / Z0-A DOI lineage reference until a dedicated v0.1.0 DOI is issued

GitHub remains the living canonical source. Hugging Face is the AI-native discovery/demo layer. Zenodo is the immutable scientific archive.

## Demo objective
The current demo is a zero-compute Static Space so the initial public surface does not require paid runtime. Future Gradio/Docker/interactive compute requires a separate runtime/cost decision.

## Completion gates
- [x] account exact URL verified
- [x] public World 8 Collection created
- [x] core repo created
- [x] forecast-hall repo created
- [x] market-data repo created
- [x] public Static Space created
- [x] GitHub canonical links present
- [x] release/DOI lineage metadata present
- [x] no secrets/private datasets intentionally exposed
- [ ] dedicated World 8 v0.1.0 Zenodo DOI created and propagated
- [ ] optional future World 8 Organization created/migration evaluated

## Credential boundary
The existing `HF_API_KEY` remains a GitHub Secret in legacy private repo `saeedfaai/world-v6`; its value is never copied into documentation or logs. It is currently used only as a temporary secure provider bridge. A future credential migration to the canonical World 8 operational boundary should preserve secrecy and least privilege.
