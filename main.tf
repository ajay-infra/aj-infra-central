# ── Namespaces ────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "argocd" {
  metadata {
    name   = "argocd"
    labels = { "app.kubernetes.io/managed-by" = "Terraform" }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name   = "monitoring"
    labels = { "app.kubernetes.io/managed-by" = "Terraform" }
  }
}

# ── LGTM S3 Storage ───────────────────────────────────────────────────────────
# Loki, Mimir, and Tempo all use S3 as their backend storage.
# Buckets are created here; Pod Identity roles grant the LGTM pods access.
# Bucket names are output so aj-platform-gitops ApplicationSets can reference them.

locals {
  lgtm_buckets = {
    loki  = local.loki_bucket
    mimir = local.mimir_bucket
    tempo = local.tempo_bucket
  }

  lgtm_retention = {
    loki  = var.loki_retention_days
    mimir = var.mimir_retention_days
    tempo = var.tempo_retention_days
  }
}

resource "aws_s3_bucket" "lgtm" {
  for_each = local.lgtm_buckets

  bucket        = each.value
  force_destroy = var.central_env != "prod"

  tags = merge(local.full_tags, { Component = each.key })
}

resource "aws_s3_bucket_versioning" "lgtm" {
  for_each = local.lgtm_buckets

  bucket = aws_s3_bucket.lgtm[each.key].id

  versioning_configuration {
    status = "Disabled" # LGTM data is immutable by design
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lgtm" {
  for_each = local.lgtm_buckets

  bucket = aws_s3_bucket.lgtm[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lgtm" {
  for_each = local.lgtm_buckets

  bucket = aws_s3_bucket.lgtm[each.key].id

  rule {
    id     = "expire-data"
    status = "Enabled"

    expiration {
      days = local.lgtm_retention[each.key]
    }
  }
}

resource "aws_s3_bucket_public_access_block" "lgtm" {
  for_each = local.lgtm_buckets

  bucket = aws_s3_bucket.lgtm[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Pod Identity — LGTM S3 access ────────────────────────────────────────────

resource "aws_iam_policy" "lgtm_s3" {
  name        = "${local.name_prefix}-lgtm-s3"
  description = "Loki, Mimir, Tempo — S3 read/write for LGTM storage backends"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LGTMBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = flatten([
          for name, bucket in aws_s3_bucket.lgtm :
          [bucket.arn, "${bucket.arn}/*"]
        ])
      },
    ]
  })

  tags = local.full_tags
}

resource "aws_iam_role" "lgtm" {
  name = "${local.name_prefix}-lgtm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = local.full_tags
}

resource "aws_iam_role_policy_attachment" "lgtm_s3" {
  role       = aws_iam_role.lgtm.name
  policy_arn = aws_iam_policy.lgtm_s3.arn
}

resource "aws_eks_pod_identity_association" "lgtm" {
  cluster_name    = local.cluster_name
  namespace       = "monitoring"
  service_account = "lgtm-storage"
  role_arn        = aws_iam_role.lgtm.arn
}
