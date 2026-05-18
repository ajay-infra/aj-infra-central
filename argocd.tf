# ── ArgoCD Hub ────────────────────────────────────────────────────────────────
# ArgoCD is installed directly here (not via aj-infra-platform).
# It is NOT managed by itself — bootstrap-argocd.yml in aj-platform-gitops
# handles upgrades via helm upgrade --install (avoids circular self-management).
#
# ksops sidecar is configured in helm-values/argocd/{env}.yaml.
# After this apply, run bootstrap-argocd.yml to create AppProjects + ApplicationSets.

resource "helm_release" "argocd" {
  name       = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version_argocd
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    file("${path.module}/helm-values/argocd/${var.central_env}.yaml")
  ]

  # Wait for all ArgoCD components to be healthy before proceeding
  wait    = true
  timeout = 600

  depends_on = [
    kubernetes_namespace.argocd,
    aws_eks_pod_identity_association.lgtm, # ensure Pod Identity is ready
  ]
}

# ── ksops KMS permissions ─────────────────────────────────────────────────────
# The ArgoCD repo-server pod (ksops sidecar) needs KMS Decrypt to render
# SOPS-encrypted Helm values files in k8s-manifests.
# KMS key ARNs come from aj-tf-module-scps outputs.

resource "aws_iam_policy" "argocd_ksops" {
  name        = "${local.name_prefix}-argocd-ksops"
  description = "ArgoCD repo-server ksops sidecar — KMS Decrypt for SOPS-encrypted manifests"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KsopsDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = "*" # Scope to specific SOPS key ARNs once known (from aj-tf-module-scps outputs)
      },
    ]
  })

  tags = local.full_tags
}

resource "aws_iam_role" "argocd" {
  name = "${local.name_prefix}-argocd"

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

resource "aws_iam_role_policy_attachment" "argocd_ksops" {
  role       = aws_iam_role.argocd.name
  policy_arn = aws_iam_policy.argocd_ksops.arn
}

resource "aws_eks_pod_identity_association" "argocd" {
  cluster_name    = local.cluster_name
  namespace       = "argocd"
  service_account = "argocd-repo-server"
  role_arn        = aws_iam_role.argocd.arn
}
