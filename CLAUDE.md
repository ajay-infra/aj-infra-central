# CLAUDE.md — aj-infra-central

> Local context file for Claude Code. Not pushed to GitHub.

## What This Repo Does

Terraform configuration for central EKS clusters (L7). NOT a reusable module —
this is an environment-specific orchestration repo like aj-infra-platform.

Two instances: central-nonprod (manages dev+staging) and central-prod (manages prod).

## Module Structure

```
providers.tf    → aws + helm + kubernetes providers (Helm/K8s need real cluster at apply)
data.tf         → aws_eks_cluster (live data), terraform_remote_state (EKS module)
variables.tf    → central_env, cluster_name, create_tgw, etc.
locals.tf       → name_prefix, lgtm bucket names
main.tf         → kubernetes_namespace, S3 buckets (loki/mimir/tempo), Pod Identity
argocd.tf       → helm_release.argocd, argocd Pod Identity (KMS decrypt for ksops)
connectivity.tf → aws_ec2_transit_gateway, optional (create_tgw), off by default —
                   peering is owned by aj-infra-networking, not here
outputs.tf      → argocd_role_arn, lgtm buckets, LGTM endpoints, TGW IDs (if created)
helm-values/    → ArgoCD Helm values per env (ksops sidecar config included)
versions.json   → pinned chart versions
```

## Key Design Decisions

- **Private repo** — contains env-specific VPC IDs, state bucket names
- **ArgoCD installed here** (not via aj-infra-platform) — central has its own platform layer
- **ArgoCD NOT self-managed** — installed AND upgraded by `helm_release.argocd` here, release name `argocd`. aj-gitops holds only what ArgoCD deploys.
- **ksops sidecar** in ArgoCD repo-server — configured in helm-values/argocd/{env}.yaml
- **Pod Identity for ArgoCD** — KMS Decrypt for ksops; no static credentials
- **LGTM endpoints are Kubernetes-internal** — become valid after ArgoCD deploys LGTM stack
- **CI: fmt+validate+security only** — plan not possible without real EKS cluster + Helm provider

## Central Cluster Connectivity

Central↔workload VPC peering is owned by **`aj-infra-networking`**, not this repo —
see its `peering.tf`. This repo only offers an optional Transit Gateway
(`connectivity.tf`, gated by `create_tgw`, default `false`), for if the org ever
crosses the documented TGW trigger (10+ VPC pairs, or on-prem/cross-region
expansion). At current scale (~4-6 VPC pairs), peering via `aj-infra-networking` is
cheaper ($0 vs ~$36/attachment/month) and already covers this — no reason to enable
TGW yet.

**Resolved 2026-08-24 — previously a 3-way conflict.** `aj-infra-release`,
`aj-infra-central` (this repo), and `aj-infra-networking` all independently
implemented the exact same central↔workload peering connections. Consolidated onto
`aj-infra-networking` since it's the dedicated network-topology repo with the more
complete isolation model (PCI/SaaS-dedicated structural isolation, not just a peering
pair). This repo's peering resources were removed; `aj-infra-release`'s
`terraform/vpc-peering-central/` was removed too.

## Apply Sequence

**Cilium is first, and the order is not negotiable.** `eks.tfvars` sets
`cni = "cilium"`, so aj-tf-module-eks strips the vpc-cni and kube-proxy addons
and installs nothing in their place. Until `helm_release.cilium` runs, the hub
has no pod networking: nodes NotReady, and no ArgoCD component can schedule
because none of them are host-networked. Cilium itself can, which is what makes
the order work.


1. aj-infra-release provision-central.yml → VPC + EKS
2. aj-infra-central terraform apply → this repo
3. kubectl apply aj-gitops projects/<class>/ + bootstrap/<class>/<tier>.yaml
4. ArgoCD auto-syncs LGTM stack
5. kubectl get svc -n monitoring → get real NLB endpoints
6. Update aj-infra-platform envs with LGTM endpoints

## Known TODOs

- [ ] Fill in VPC IDs, subnet IDs, route table IDs in envs/*.tfvars after cluster provisioned
- [ ] Narrow KMS Decrypt in argocd_ksops policy to specific key ARNs from aj-tf-module-scps
- [ ] Add GitHub OAuth config to ArgoCD Helm values once OAuth App is created
- [ ] Consider LGTM endpoint exposure via internal NLB for workload cluster Alloy push
