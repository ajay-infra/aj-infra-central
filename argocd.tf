# ── ArgoCD Hub ────────────────────────────────────────────────────────────────
# ArgoCD is installed directly here (not via aj-infra-platform), and this is the
# ONLY declaration of that install. It is not self-managed, by design: aj-gitops
# holds what ArgoCD deploys, never what deploys ArgoCD.
#
# aj-gitops used to carry a second installer — bootstrap-argocd.yml, installing
# release `argocd` from its own values — while this one installed release
# `argo-cd`. Different release names mean every resource is named differently
# (`argocd-server` vs `argo-cd-argocd-server`), so running both produced two
# complete parallel installs rather than an upgrade. Found by rendering both
# (aj-gitops#24). The release here is now `argocd`, and that workflow was
# DELETED in aj-gitops#25 rather than relocated. An earlier version of this
# comment said it would move to aj-infra as a break-glass path; that plan was
# dropped before #25 was written, and this sentence was the only place it
# survived. Two reasons it was dropped: aj-infra#53-#56 spent four PRs removing
# apply machinery that cannot run under Stage 1, and once ArgoCD is
# Terraform-managed, Terraform is itself the recovery path — the break-glass
# argument only held while ArgoCD was going to self-manage.
#
# ksops sidecar is configured in helm-values/argocd/<class>-<tier>.yaml.
# After this apply, apply aj-gitops bootstrap/<class>/<tier>.yaml to create the
# AppProjects and ApplicationSets.

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version_argocd
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    file("${path.module}/helm-values/argocd/${var.central_class}-${var.central_tier}.yaml")
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
# SOPS-encrypted Helm values files in aj-cluster-baseline.
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
