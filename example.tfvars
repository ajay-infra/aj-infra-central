# example.tfvars — used for CI fmt/validate only (no plan — needs real EKS cluster)

central_env = "nonprod"
aws_region  = "us-east-1"

state_bucket  = "tf-state-central-123456789012"
eks_state_key = "central/eks-blue/terraform.tfstate"
cluster_name  = "central-nonprod-blue"

central_vpc_id = "vpc-0central123456"

# create_tgw defaults to false — peering (owned by aj-infra-networking) covers current scale

chart_version_argocd = "7.7.11"
github_org           = "ajay-infra"

loki_retention_days  = 30
mimir_retention_days = 90
tempo_retention_days = 14

team        = "infra-core"
cost_center = "infra-2026-q1"
