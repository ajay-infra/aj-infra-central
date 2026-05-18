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
variables.tf    → central_env, cluster_name, connectivity_mode, workload_vpcs, etc.
locals.tf       → name_prefix, lgtm bucket names, peering/route cross-products
main.tf         → kubernetes_namespace, S3 buckets (loki/mimir/tempo), Pod Identity
argocd.tf       → helm_release.argocd, argocd Pod Identity (KMS decrypt for ksops)
connectivity.tf → aws_vpc_peering_connection OR aws_ec2_transit_gateway (mode toggle)
outputs.tf      → argocd_role_arn, lgtm buckets, LGTM endpoints, peering/TGW IDs
helm-values/    → ArgoCD Helm values per env (ksops sidecar config included)
versions.json   → pinned chart versions
```

## Key Design Decisions

- **Private repo** — contains env-specific VPC IDs, state bucket names
- **ArgoCD installed here** (not via aj-infra-platform) — central has its own platform layer
- **ArgoCD NOT self-managed** — bootstrap-argocd.yml in aj-platform-gitops handles upgrades
- **ksops sidecar** in ArgoCD repo-server — configured in helm-values/argocd/{env}.yaml
- **Pod Identity for ArgoCD** — KMS Decrypt for ksops; no static credentials
- **LGTM endpoints are Kubernetes-internal** — become valid after ArgoCD deploys LGTM stack
- **connectivity_mode toggle** — peering (default, ≤10 VPCs) or tgw (10+ VPCs)
- **CI: fmt+validate+security only** — plan not possible without real EKS cluster + Helm provider

## Apply Sequence

1. aj-infra-release provision-central.yml → VPC + EKS
2. aj-infra-central terraform apply → this repo
3. aj-platform-gitops bootstrap-argocd.yml → ArgoCD projects + ApplicationSets
4. ArgoCD auto-syncs LGTM stack
5. kubectl get svc -n monitoring → get real NLB endpoints
6. Update aj-infra-platform envs with LGTM endpoints

## Known TODOs

- [ ] Fill in VPC IDs, subnet IDs, route table IDs in envs/*.tfvars after cluster provisioned
- [ ] Narrow KMS Decrypt in argocd_ksops policy to specific key ARNs from aj-tf-module-scps
- [ ] Add GitHub OAuth config to ArgoCD Helm values once OAuth App is created
- [ ] Consider LGTM endpoint exposure via internal NLB for workload cluster Alloy push
