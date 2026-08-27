# World 8 v0.1.0 — Release Gate

Status: OPEN

## Required before publish
- exact commit frozen
- architecture validator passes
- developer-admission validator passes
- identity/authority validator passes
- secrets/privacy scan passes
- release body matches shipped contents
- repository visibility decision recorded
- tag `v0.1.0` created
- GitHub Release object published

## Required immediately after publish
- record release URL and tag commit
- create exact Zenodo snapshot + DOI
- append new DOI to `EXTERNAL_LINKS.md`
- sync Drive publication registries
- mirror release metadata to Hugging Face when organization is active

## Current blocker
The connected GitHub write surface in this ChatGPT session does not expose tag/release creation. Remote Desktop is not connected, so the final GitHub `Publish release` action cannot be executed from this session yet. All release content and documentation are prepared in-repository.
