locals {
  name_prefix  = "central-${var.central_env}"
  account_id   = data.aws_caller_identity.current.account_id
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name

  # LGTM S3 bucket names — deterministic, referenced by helm-values ArgoCD ApplicationSet
  loki_bucket  = "${local.name_prefix}-loki-chunks"
  mimir_bucket = "${local.name_prefix}-mimir-blocks"
  tempo_bucket = "${local.name_prefix}-tempo-traces"

  # VPC peering cross-product: workload VPC × central route table
  peering_route_pairs = {
    for pair in setproduct(keys(var.workload_vpcs), var.central_private_route_table_ids) :
    "${pair[0]}--${pair[1]}" => {
      workload_name  = pair[0]
      route_table_id = pair[1]
      cidr           = var.workload_vpcs[pair[0]].vpc_cidr
    }
  }

  # Route pairs for adding central CIDR back into workload VPC route tables
  workload_route_pairs = {
    for pair in flatten([
      for name, vpc in var.workload_vpcs : [
        for rt_id in vpc.private_route_table_ids : {
          key            = "${name}--${rt_id}"
          workload_name  = name
          route_table_id = rt_id
          cidr           = var.central_vpc_cidr
        }
      ]
    ]) : pair.key => pair
  }

  full_tags = merge({
    Project     = "aj-infra-platform"
    ManagedBy   = "Terraform"
    Repository  = "aj-infra-central"
    Environment = "central-${var.central_env}"
    Team        = var.team
    CostCenter  = var.cost_center
  }, var.tags)
}
