locals {
  name_prefix  = "central-${var.central_class}-${var.central_tier}"
  account_id   = data.aws_caller_identity.current.account_id
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name

  # LGTM S3 bucket names — deterministic, referenced by helm-values ArgoCD ApplicationSet
  loki_bucket  = "${local.name_prefix}-loki-chunks"
  mimir_bucket = "${local.name_prefix}-mimir-blocks"
  tempo_bucket = "${local.name_prefix}-tempo-traces"

  full_tags = merge({
    Project     = "aj-infra-platform"
    ManagedBy   = "Terraform"
    Repository  = "aj-infra-central"
    Environment = "central-${var.central_class}-${var.central_tier}"
    Team        = var.team
    CostCenter  = var.cost_center
  }, var.tags)
}
