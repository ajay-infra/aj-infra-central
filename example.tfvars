# example.tfvars — used for CI fmt/validate only (no plan — needs real EKS cluster)

central_env = "nonprod"
aws_region  = "us-east-1"

state_bucket  = "tf-state-central-123456789012"
eks_state_key = "central/eks-blue/terraform.tfstate"
cluster_name  = "central-nonprod-blue"

central_vpc_id                  = "vpc-0central123456"
central_vpc_cidr                = "10.200.0.0/16"
central_private_route_table_ids = ["rtb-0aaa111", "rtb-0bbb222"]

connectivity_mode = "peering"

workload_vpcs = {
  dev-blue = {
    vpc_id                  = "vpc-0dev111"
    vpc_cidr                = "10.100.0.0/16"
    private_route_table_ids = ["rtb-0dev111"]
  }
}

chart_version_argocd = "7.7.11"
github_org           = "ajay-infra"

loki_retention_days  = 30
mimir_retention_days = 90
tempo_retention_days = 14

team        = "infra-core"
cost_center = "infra-2026-q1"
