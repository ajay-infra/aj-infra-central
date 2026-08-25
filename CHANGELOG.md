# Changelog

All notable changes to this repo are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Fixed
- `README.md`'s "Provider pins" table said Terraform `= 1.7.5` — `providers.tf` actually pins `= 1.10.5`, matching the platform-wide Terraform 1.10.5 migration already reflected everywhere else. Same stale-version pattern already found and fixed in every `aj-tf-module-*` repo touched this project.
- No `skills.md` existed at all — added one, following the same shape used for `aj-infra-platform` (another non-reusable, environment-specific orchestration repo). Without it, `infra-developer`/`infra-reviewer` had no repo-context source for this repo per the farm's two-source context model.
- Confirmed (via reading `main.tf`, `argocd.tf`, `connectivity.tf`, `outputs.tf`) that this repo is fully implemented: real S3 buckets + Pod Identity for LGTM storage, real ArgoCD Helm install with ksops KMS decrypt wiring, real VPC peering/TGW connectivity with a mode toggle. `aj-infra-release/CLAUDE.md`'s `provision-central.yml` stage list currently still describes this repo as `central-platform → PLACEHOLDER (aj-infra-central not yet built)` — that claim is stale and was not touched in this PR (out of scope for this repo), but is noted in the new `skills.md`'s Agentic capabilities section so it surfaces the next time either repo is worked on.

## [v1.0.0] - 2026-08-24

Initial release — ArgoCD hub (with ksops sidecar) + Grafana LGTM S3/IAM storage backend + central↔workload VPC connectivity (peering or Transit Gateway) for a central EKS cluster. Repo was already fully implemented; this tag just formalizes the first stable release so `skills.md` has something real to pin to.
