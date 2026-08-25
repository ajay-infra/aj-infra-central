# ── ArgoCD ────────────────────────────────────────────────────────────────────

output "argocd_role_arn" {
  description = "ArgoCD repo-server Pod Identity role ARN — pass to aj-tf-module-scps argocd_role_arns."
  value       = aws_iam_role.argocd.arn
}

# ── LGTM S3 Buckets ───────────────────────────────────────────────────────────

output "loki_bucket" {
  description = "S3 bucket name for Loki chunks. Pass to aj-platform-gitops ApplicationSet parameters."
  value       = aws_s3_bucket.lgtm["loki"].bucket
}

output "mimir_bucket" {
  description = "S3 bucket name for Mimir blocks. Pass to aj-platform-gitops ApplicationSet parameters."
  value       = aws_s3_bucket.lgtm["mimir"].bucket
}

output "tempo_bucket" {
  description = "S3 bucket name for Tempo traces. Pass to aj-platform-gitops ApplicationSet parameters."
  value       = aws_s3_bucket.lgtm["tempo"].bucket
}

output "lgtm_role_arn" {
  description = "LGTM Pod Identity role ARN — used in LGTM Helm values for S3 access."
  value       = aws_iam_role.lgtm.arn
}

# ── LGTM Push Endpoints ───────────────────────────────────────────────────────
# These are the internal service DNS names workload clusters use to push telemetry.
# They become valid after the LGTM stack is deployed by ArgoCD from aj-platform-gitops.
# Update aj-infra-platform envs/*.tfvars with these values after LGTM is running.
# Run: kubectl get svc -n monitoring to confirm actual service endpoints.

output "loki_push_endpoint" {
  description = <<-EOT
    Loki log push endpoint for Alloy on workload clusters.
    Valid after ArgoCD deploys the LGTM stack (aj-platform-gitops).
    Update aj-infra-platform loki_endpoint variable with this value.
  EOT
  value       = "http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push"
}

output "mimir_remote_write_endpoint" {
  description = <<-EOT
    Mimir metrics remote-write endpoint for Alloy on workload clusters.
    Valid after ArgoCD deploys the LGTM stack (aj-platform-gitops).
  EOT
  value       = "http://mimir-nginx.monitoring.svc.cluster.local/api/v1/push"
}

output "tempo_otlp_endpoint" {
  description = <<-EOT
    Tempo OTLP gRPC endpoint for Alloy on workload clusters.
    Valid after ArgoCD deploys the LGTM stack (aj-platform-gitops).
  EOT
  value       = "http://tempo.monitoring.svc.cluster.local:4317"
}

# ── Connectivity ──────────────────────────────────────────────────────────────
# Central↔workload VPC peering connection IDs are owned by aj-infra-networking's
# own outputs, not here — see CLAUDE.md Central Cluster Connectivity.

output "transit_gateway_id" {
  description = "Transit Gateway ID (only set when create_tgw = true). Share to workload accounts via RAM."
  value       = var.create_tgw ? aws_ec2_transit_gateway.main[0].id : null
}

output "transit_gateway_ram_share_arn" {
  description = "RAM resource share ARN for TGW (only set when create_tgw = true)."
  value       = var.create_tgw ? aws_ram_resource_share.tgw[0].arn : null
}
