# central-nonprod — manages dev + staging workload clusters

central_env = "nonprod"
aws_region  = "us-east-1"

# From aj-infra-release provision-central.yml outputs
state_bucket  = "REPLACE_WITH_TF_STATE_BUCKET"
eks_state_key = "central/eks-blue/terraform.tfstate"
cluster_name  = "central-nonprod-blue"

# Management VPC (10.200.0.0/16 from CLAUDE.md CIDR plan)
central_vpc_id   = "REPLACE_WITH_CENTRAL_NONPROD_VPC_ID"
central_vpc_cidr = "10.200.0.0/16"
central_private_route_table_ids = [
  # REPLACE with private route table IDs from central VPC
]

# VPC Peering — recommended for ≤10 VPC pairs
connectivity_mode = "peering"

# Workload VPCs to peer with (dev + staging)
workload_vpcs = {
  dev-blue = {
    vpc_id                  = "REPLACE_WITH_DEV_VPC_ID"
    vpc_cidr                = "10.100.0.0/16"
    private_route_table_ids = []
  }
  staging-blue = {
    vpc_id                  = "REPLACE_WITH_STAGING_VPC_ID"
    vpc_cidr                = "10.110.0.0/16"
    private_route_table_ids = []
  }
}

# ArgoCD
chart_version_argocd = "7.7.11"
github_org           = "ajay-infra"

# LGTM retention (nonprod — shorter)
loki_retention_days  = 30
mimir_retention_days = 90
tempo_retention_days = 14

team        = "infra-core"
cost_center = "infra-2026-q1"
