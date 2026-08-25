# central-prod — manages prod workload clusters

central_env = "prod"
aws_region  = "us-east-1"

state_bucket  = "REPLACE_WITH_TF_STATE_BUCKET"
eks_state_key = "central/prod/eks-blue/terraform.tfstate"
cluster_name  = "central-prod-blue"

central_vpc_id = "REPLACE_WITH_CENTRAL_PROD_VPC_ID"

# Central↔workload VPC peering is provisioned by aj-infra-networking, not here —
# see CLAUDE.md Central Cluster Connectivity. Only set create_tgw = true if the
# org crosses the TGW trigger (10+ VPC pairs / on-prem expansion).
# create_tgw = true

chart_version_argocd = "7.7.11"
github_org           = "ajay-infra"

# LGTM retention (prod — longer)
loki_retention_days  = 90
mimir_retention_days = 365
tempo_retention_days = 30

team        = "infra-core"
cost_center = "infra-2026-q1"
