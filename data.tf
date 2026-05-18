# Central EKS cluster — reads live cluster info for Helm/Kubernetes providers
data "aws_eks_cluster" "central" {
  name = var.cluster_name
}

data "aws_caller_identity" "current" {}

# Remote state from the EKS module that provisioned this central cluster
# Provides: cluster endpoint, CA, node role ARNs, active subnets
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = var.eks_state_key
    region = var.aws_region
  }
}
