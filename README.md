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
| `aws_vpc_peering_connection` | Central VPC ↔ workload VPCs (peering mode) |
| `aws_route` (both directions) | RFC1918 routing between central and workload VPCs |
| `aws_ec2_transit_gateway` (optional) | TGW for 10+ VPCs or cross-account (tgw mode) |

---

## Apply order

```
Stage C1: aj-infra-release/provision-central.yml
          → VPC + EKS cluster (central-nonprod or central-prod)

Stage C2: aj-infra-central (this repo)
          → S3 buckets, Pod Identity, ArgoCD Helm install, VPC peering/TGW

Stage C3: aj-platform-gitops/bootstrap-argocd.yml
          → ArgoCD AppProjects + bootstrap ApplicationSet
          → ArgoCD syncs LGTM stack from aj-platform-gitops

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

After ArgoCD deploys the LGTM stack (from `aj-platform-gitops`), the following endpoints are available to Alloy on workload clusters. Update `aj-infra-platform` envs with these:

```
loki_push_endpoint          = http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push
mimir_remote_write_endpoint = http://mimir-nginx.monitoring.svc.cluster.local/api/v1/push
tempo_otlp_endpoint         = http://tempo.monitoring.svc.cluster.local:4317
```

These are `outputs` of this module but become valid only after the LGTM Helm charts are deployed by ArgoCD. Run `kubectl get svc -n monitoring` to confirm.

---

## Connectivity mode

Set in `envs/central-*.tfvars`:

```hcl
connectivity_mode = "peering"  # recommended for this scale (~4–6 VPC pairs)
# connectivity_mode = "tgw"   # use for 10+ VPCs or on-prem expansion
```

See `CLAUDE.md` Central Cluster Connectivity section for cost comparison. At this scale (< 10 VPC pairs), peering saves ~$150+/month vs TGW.

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
# aj-platform-gitops/bootstrap-argocd.yml action=install

# 4. ArgoCD syncs LGTM stack automatically
# 5. Update aj-infra-platform envs with LGTM endpoints
```

---

## Provider pins

| Tool | Version |
|---|---|
| Terraform | `= 1.7.5` |
| AWS provider | `= 5.100.0` |
| Helm provider | `= 2.12.1` |
| Kubernetes provider | `= 2.27.0` |
