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

variable "central_vpc_cidr" {
  type        = string
  description = "Central management VPC CIDR (e.g. 10.200.0.0/16 for nonprod, 10.201.0.0/16 for prod)."
}

variable "central_private_route_table_ids" {
  type        = list(string)
  description = "Central VPC private route table IDs — peering routes to workload VPCs are added here."
}

# ── Connectivity ──────────────────────────────────────────────────────────────

variable "connectivity_mode" {
  type        = string
  description = <<-EOT
    How the central cluster connects to workload clusters.
    peering — VPC Peering (recommended for ≤10 VPC pairs; $0 attachment fee)
    tgw     — Transit Gateway (for 10+ VPCs or on-prem / cross-region expansion)
    See CLAUDE.md Central Cluster Connectivity section for full trade-off analysis.
  EOT
  default     = "peering"
  validation {
    condition     = contains(["peering", "tgw"], var.connectivity_mode)
    error_message = "connectivity_mode must be 'peering' or 'tgw'."
  }
}

variable "workload_vpcs" {
  type = map(object({
    vpc_id                  = string
    vpc_cidr                = string
    private_route_table_ids = list(string) # workload VPC route tables — central CIDR routes added here
  }))
  description = <<-EOT
    Map of workload cluster name → VPC details for connectivity setup.
    Example: {
      dev-blue     = { vpc_id = "vpc-...", vpc_cidr = "10.100.0.0/16", private_route_table_ids = [...] }
      staging-blue = { vpc_id = "vpc-...", vpc_cidr = "10.110.0.0/16", private_route_table_ids = [...] }
    }
  EOT
  default     = {}
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
