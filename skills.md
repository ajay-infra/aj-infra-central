# skills.md — aj-infra-central

## Purpose
Platform layer for a central EKS cluster (ArgoCD hub + Grafana LGTM storage/IAM):
ArgoCD Helm install (with ksops sidecar for SOPS-encrypted manifests), LGTM S3 buckets
+ Pod Identity, and central↔workload VPC connectivity (peering or Transit Gateway).
Not a reusable module — applied directly against `central-nonprod` or `central-prod`,
similar in shape to `aj-infra-platform`. Reads the central EKS cluster's details via
`data.terraform_remote_state.eks`, not a module call.

## Type
`tf-config` (environment-specific orchestration, not a `source =` module — same shape as `aj-infra-platform`)

## Stable ref
```
source = "github.com/ajay-infra/aj-infra-central?ref=v1.0.0"
```

## Key inputs
| Variable | Description |
|---|---|
| `central_env` | `nonprod` \| `prod` |
| `state_bucket` / `eks_state_key` | Where to read the central EKS module's remote state from |
| `cluster_name` | Central EKS cluster name (must match what `aj-infra-release` provisioned) |
| `central_vpc_id` / `central_vpc_cidr` / `central_private_route_table_ids` | Central management VPC details |
| `connectivity_mode` | `peering` (≤10 VPC pairs, default) \| `tgw` (10+ VPCs / cross-region) |
| `workload_vpcs` | Map of workload cluster name → VPC details for peering/TGW routes |
| `chart_version_argocd` | ArgoCD Helm chart version |
| `loki_retention_days` / `mimir_retention_days` / `tempo_retention_days` | LGTM S3 lifecycle expiration per backend |

## Key outputs
| Output | Description |
|---|---|
| `argocd_role_arn` | ArgoCD repo-server Pod Identity role ARN — pass to `aj-tf-module-scps` |
| `loki_bucket` / `mimir_bucket` / `tempo_bucket` | LGTM S3 bucket names — pass to `aj-gitops` ApplicationSet params |
| `lgtm_role_arn` | LGTM Pod Identity role ARN |
| `loki_push_endpoint` / `mimir_remote_write_endpoint` / `tempo_otlp_endpoint` | In-cluster service DNS — only valid after ArgoCD deploys the LGTM stack |
| `peering_connection_ids` / `transit_gateway_id` / `transit_gateway_ram_share_arn` | Connectivity resources — populated depending on `connectivity_mode` |

## Depends on
`aj-infra-release/provision-central.yml` — provisions the VPC + EKS cluster this repo installs onto (via `aj-tf-module-vpc` + `aj-tf-module-eks`). This repo reads that cluster's state via `data.terraform_remote_state.eks`, not a module call. After this repo applies, `aj-gitops`'s `bootstrap/<class>/<tier>.yaml` is applied to create the ArgoCD AppProjects/ApplicationSets and trigger the actual LGTM Helm sync.

## AWS tags applied
`Project`, `ManagedBy`, `Repository`, `Environment` (`central-<central_env>`), `Team`,
`CostCenter` (set in `locals.full_tags`), plus whatever's in `var.tags`. LGTM S3 buckets
additionally get a `Component` tag (`loki`/`mimir`/`tempo`).

## Branching convention
- `main` — active development
- semver tags (`v1.0.0`, ...) — stable pinned releases

## CI checks
fmt, validate, security scan (no plan — Helm/Kubernetes providers require a live EKS
cluster at apply time, so a meaningful dry-run plan isn't possible without one)

## Agentic capabilities
- Detect chart version drift for `chart_version_argocd` vs `versions.json`
- Validate `connectivity_mode = "tgw"` isn't set for fewer than ~10 workload VPCs (peering is cheaper at this scale)
- Flag if `workload_vpcs` is missing an entry for a cluster that `aj-infra-release` has already provisioned
- Cross-check this repo's actual implementation status against any other repo's docs that describe it as a placeholder (see `aj-infra-release/CLAUDE.md`'s `provision-central.yml` stage list, which as of this writing still says `central-platform → PLACEHOLDER (aj-infra-central not yet built)` — that claim is stale; this repo is fully implemented)
