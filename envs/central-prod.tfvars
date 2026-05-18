# central-prod — manages prod workload clusters

central_env = "prod"
aws_region  = "us-east-1"

state_bucket  = "REPLACE_WITH_TF_STATE_BUCKET"
eks_state_key = "central/prod/eks-blue/terraform.tfstate"
cluster_name  = "central-prod-blue"

central_vpc_id                  = "REPLACE_WITH_CENTRAL_PROD_VPC_ID"
central_vpc_cidr                = "10.201.0.0/16"
central_private_route_table_ids = []

connectivity_mode = "peering"

workload_vpcs = {
  prod-blue = {
    vpc_id                  = "REPLACE_WITH_PROD_BLUE_VPC_ID"
    vpc_cidr                = "10.120.0.0/16"
    private_route_table_ids = []
  }
  prod-green = {
    vpc_id                  = "REPLACE_WITH_PROD_GREEN_VPC_ID"
    vpc_cidr                = "10.121.0.0/16"
    private_route_table_ids = []
  }
}

chart_version_argocd = "7.7.11"
github_org           = "ajay-infra"

# LGTM retention (prod — longer)
loki_retention_days  = 90
mimir_retention_days = 365
tempo_retention_days = 30

team        = "infra-core"
cost_center = "infra-2026-q1"
