# ── Core ──────────────────────────────────────────────────────────────────────

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "central_class" {
  type        = string
  description = "Which model this hub serves: product or saas."
  validation {
    condition     = contains(["product", "saas"], var.central_class)
    error_message = "central_class must be 'product' or 'saas'."
  }
}

variable "central_tier" {
  type        = string
  description = "Central cluster tier: nonprod or prod."
  validation {
    condition     = contains(["nonprod", "prod"], var.central_tier)
    error_message = "central_tier must be 'nonprod' or 'prod'."
  }
}

# WAS a single `central_env` string, valid only as "nonprod" or "prod". When
# aj-infra grew a hub per class it started passing "saas-prod", which failed
# that validation outright — loudly, which was lucky, because the two other
# readers of the same string would have failed QUIETLY:
#
#   force_destroy = var.central_env != "prod"
#       "saas-prod" != "prod" is TRUE, so the production SaaS LGTM buckets
#       would have been created with force_destroy enabled.
#
#   helm-values/argocd/${var.central_env}.yaml
#       no saas-prod.yaml exists.
#
# One string carrying two facts is why. They are two variables now.

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

variable "install_keycloak" {
  type        = bool
  description = <<-EOT
    Install Keycloak in this central cluster.

    Central, not per-workload-cluster: aj-infra-platform is applied to every
    workload cluster, so Keycloak there would mean six Keycloaks and therefore
    six issuers. Issuer count must not grow with clusters any more than it grows
    with tenants. Two central environments means two Keycloaks, constant.

    OFF by default: Keycloak needs a database and none exists yet. It is
    configured for production mode, so it refuses to start without one rather
    than silently running on H2 and losing every user on restart. See
    aj-infra-context#24.
  EOT
  default     = false
}

variable "chart_version_keycloak" {
  type    = string
  default = "7.3.0"
}

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
