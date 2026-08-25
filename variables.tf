# ── Core ──────────────────────────────────────────────────────────────────────

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "central_env" {
  type        = string
  description = "Central cluster tier: nonprod (serves dev+staging) or prod (serves prod)."
  validation {
    condition     = contains(["nonprod", "prod"], var.central_env)
    error_message = "central_env must be 'nonprod' or 'prod'."
  }
}

# ── Remote State ──────────────────────────────────────────────────────────────

variable "state_bucket" {
  type        = string
  description = "S3 bucket holding Terraform state for all modules."
}

variable "eks_state_key" {
  type        = string
  description = "S3 key for the central EKS module state. e.g. central/eks-blue/terraform.tfstate"
}

variable "cluster_name" {
  type        = string
  description = "Central EKS cluster name. Must match what was provisioned by aj-infra-release."
}

# ── Network ───────────────────────────────────────────────────────────────────

variable "central_vpc_id" {
  type        = string
  description = "Central cluster management VPC ID."
}

# ── Connectivity ──────────────────────────────────────────────────────────────
# Central↔workload VPC peering is owned by aj-infra-networking, not here — see
# connectivity.tf and CLAUDE.md "Central Cluster Connectivity" for why. The only
# connectivity option this repo still offers is an optional Transit Gateway.

variable "create_tgw" {
  type        = bool
  description = <<-EOT
    Create a Transit Gateway for workload connectivity. Off by default — the org
    is well under the documented trigger (10+ VPC pairs, or on-prem/cross-region
    expansion) for needing one; peering via aj-infra-networking covers current
    scale at $0 attachment cost. See CLAUDE.md Central Cluster Connectivity.
  EOT
  default     = false
}

# ── ArgoCD ────────────────────────────────────────────────────────────────────

variable "chart_version_argocd" {
  type    = string
  default = "7.7.11"
}

variable "github_org" {
  type        = string
  description = "GitHub org name for ArgoCD GitHub OAuth SSO (e.g. 'ajay-infra')."
  default     = "ajay-infra"
}

variable "argocd_github_client_id" {
  type        = string
  description = "GitHub OAuth App client ID for ArgoCD SSO. Store in Secrets Manager."
  default     = ""
}

variable "argocd_github_client_secret_arn" {
  type        = string
  description = "Secrets Manager ARN for GitHub OAuth App client secret."
  default     = ""
}

# ── LGTM Storage ──────────────────────────────────────────────────────────────

variable "loki_retention_days" {
  type        = number
  description = "Loki log retention in days."
  default     = 30
}

variable "mimir_retention_days" {
  type        = number
  description = "Mimir metrics retention in days."
  default     = 90
}

variable "tempo_retention_days" {
  type        = number
  description = "Tempo trace retention in days."
  default     = 14
}

# ── Tags ──────────────────────────────────────────────────────────────────────

variable "team" {
  type    = string
  default = "infra-core"
}

variable "cost_center" {
  type    = string
  default = "infra-2026-q1"
}

variable "tags" {
  type    = map(string)
  default = {}
}
