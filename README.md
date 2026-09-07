# aj-infra-central

Terraform configuration for the central EKS clusters (L7 in the platform stack). Each central cluster is an ArgoCD hub + Grafana LGTM stack that manages all workload clusters in its tier.

This is **not a reusable module** — it is a concrete environment configuration, similar to `aj-infra-platform`. It calls `aj-tf-module-vpc` and `aj-tf-module-eks` via `aj-infra-release`, then this repo configures what runs on top.

---

## Two central clusters

| Cluster | Manages | CIDR |
|---|---|---|
| `central-nonprod` | dev + staging workload clusters | 10.200.0.0/16 |
| `central-prod` | prod workload clusters | 10.201.0.0/16 |

Both clusters are provisioned by `aj-infra-release/provision-central.yml`. This repo configures the platform layer on top.

---

## What this repo provisions

| Resource | Purpose |
|---|---|
| `aws_s3_bucket` (loki, mimir, tempo) | LGTM backend storage (90-day metrics, 30-day logs) |
| `aws_iam_role.lgtm` + Pod Identity | LGTM pods can write/read S3 without static keys |
| `helm_release.argocd` | ArgoCD hub with ksops sidecar (SOPS decrypt via KMS) |
| `aws_iam_role.argocd` + Pod Identity | ArgoCD repo-server can call KMS Decrypt for ksops |
| `aws_ec2_transit_gateway` (optional, `create_tgw = true`) | TGW for 10+ VPCs or cross-account — peering (default) is owned by `aj-infra-networking`, not here |

---

## Apply order

```
Stage C1: aj-infra-release/provision-central.yml
          → VPC + EKS cluster (central-nonprod or central-prod)

Stage C2: aj-infra-central (this repo)
          → S3 buckets, Pod Identity, ArgoCD Helm install, optional TGW

Stage C2b: aj-infra-networking
          → Central↔workload VPC peering (can run in parallel with C2)

Stage C3: kubectl apply aj-gitops bootstrap/<class>/<tier>.yaml
          → ArgoCD AppProjects + bootstrap Application
          → ArgoCD syncs the LGTM stack from aj-gitops

Stage C4: Update aj-infra-platform envs with LGTM endpoints
          → Alloy on workload clusters starts pushing telemetry to central
```

---

## Hub-spoke architecture

```
central-nonprod cluster:
  ArgoCD hub  ──manages──► dev cluster + staging cluster
  Grafana LGTM ◄─receives─  Alloy on dev + staging clusters

central-prod cluster:
  ArgoCD hub  ──manages──► prod-blue cluster + prod-green cluster
  Grafana LGTM ◄─receives─  Alloy on prod clusters
```

VPC peering (or TGW) carries Alloy telemetry push traffic and ArgoCD agent traffic between cluster VPCs.

---

## LGTM endpoints

After ArgoCD deploys the LGTM stack (from `aj-gitops`), the following endpoints are available to Alloy on workload clusters. Update `aj-infra-platform` envs with these:

```
loki_push_endpoint          = http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push
mimir_remote_write_endpoint = http://mimir-nginx.monitoring.svc.cluster.local/api/v1/push
tempo_otlp_endpoint         = http://tempo.monitoring.svc.cluster.local:4317
```

These are `outputs` of this module but become valid only after the LGTM Helm charts are deployed by ArgoCD. Run `kubectl get svc -n monitoring` to confirm.

---

## Connectivity mode

Central↔workload VPC peering is provisioned by **`aj-infra-networking`**, not this
repo. This repo only offers an optional Transit Gateway, off by default:

```hcl
# envs/central-*.tfvars
create_tgw = true   # only if the org crosses the TGW trigger (10+ VPC pairs / on-prem)
```

See `CLAUDE.md` Central Cluster Connectivity section for the cost comparison and the
history of why peering moved to `aj-infra-networking`.

---

## ArgoCD ksops plugin

The ksops sidecar on the ArgoCD repo-server decrypts SOPS-encrypted Helm values at render time. Setup:

1. `aj-tf-module-scps` outputs KMS key ARNs per environment
2. This repo's `argocd.tf` creates a Pod Identity role with `kms:Decrypt`
3. The ksops sidecar container is configured in `helm-values/argocd/{env}.yaml`
4. Engineers encrypt secrets with `sops -e`; ArgoCD decrypts at render time

---

## Applying

```bash
# 1. Bootstrap the central cluster first
# aj-infra-release/provision-central.yml → runs VPC + EKS

# 2. Apply this repo
terraform init \
  -backend-config="bucket=tf-state-central-123456789012" \
  -backend-config="key=central/nonprod/terraform.tfstate" \
  -backend-config="region=us-east-1"

terraform apply -var-file=envs/central-nonprod.tfvars

# 3. Bootstrap ArgoCD projects + ApplicationSets
# kubectl apply -f aj-gitops/projects/<class>/{platform,workloads}.yaml
# kubectl apply -f aj-gitops/bootstrap/<class>/<tier>.yaml

# 4. ArgoCD syncs LGTM stack automatically
# 5. Update aj-infra-platform envs with LGTM endpoints
```

---

## Provider pins

| Tool | Version |
|---|---|
| Terraform | `= 1.10.5` |
| AWS provider | `= 5.100.0` |
| Helm provider | `= 2.12.1` |
| Kubernetes provider | `= 2.27.0` |
