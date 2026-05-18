terraform {
  required_version = "= 1.7.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.100.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "= 2.12.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 2.27.0"
    }
  }

  # Backend configured dynamically by pipelines via -backend-config
  # backend "s3" {
  #   bucket         = "<tf-state-bucket>"
  #   key            = "central/<env>/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "tf-locks-central"
  #   role_arn       = "arn:aws:iam::ACCOUNT_ID:role/GitHubActions-Terraform"
  # }
}

provider "aws" {
  region = var.aws_region

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  default_tags {
    tags = local.full_tags
  }
}

# Helm and Kubernetes providers connect to the central EKS cluster.
# Requires real credentials at apply time. terraform validate works without them.
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.central.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.central.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
    }
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.central.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.central.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
  }
}
