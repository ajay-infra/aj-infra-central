# ── Central ↔ Workload VPC Connectivity ──────────────────────────────────────
# Alloy on workload clusters pushes telemetry to the central cluster's LGTM stack.
# ArgoCD hub on the central cluster manages workload cluster syncs.
# Both require network connectivity between central VPC and workload VPCs.
#
# connectivity_mode = "peering" — VPC Peering (recommended for ≤10 VPC pairs)
# connectivity_mode = "tgw"    — Transit Gateway (for 10+ VPCs, on-prem, cross-region)
#
# See CLAUDE.md "Central Cluster Connectivity" for full trade-off analysis.

# ── VPC Peering Mode ──────────────────────────────────────────────────────────

# Peering connection from central VPC to each workload VPC
resource "aws_vpc_peering_connection" "workload" {
  for_each = var.connectivity_mode == "peering" ? var.workload_vpcs : {}

  vpc_id      = var.central_vpc_id
  peer_vpc_id = each.value.vpc_id
  auto_accept = true # same account — auto-accept

  tags = merge(local.full_tags, {
    Name = "${local.name_prefix}-to-${each.key}"
  })
}

# Routes in central VPC → workload VPC CIDRs (one per route table × workload VPC)
resource "aws_route" "central_to_workload" {
  for_each = var.connectivity_mode == "peering" ? local.peering_route_pairs : {}

  route_table_id            = each.value.route_table_id
  destination_cidr_block    = each.value.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.workload[each.value.workload_name].id
}

# Routes in workload VPCs → central VPC CIDR (one per workload route table)
# NOTE: This requires Terraform to have IAM access in the workload accounts.
# In a multi-account setup, use a cross-account assume_role or manage these
# routes in aj-infra-release/terraform/vpc-peering-central/ instead.
resource "aws_route" "workload_to_central" {
  for_each = var.connectivity_mode == "peering" ? local.workload_route_pairs : {}

  route_table_id            = each.value.route_table_id
  destination_cidr_block    = each.value.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.workload[each.value.workload_name].id
}

# ── Transit Gateway Mode ──────────────────────────────────────────────────────
# Activated when connectivity_mode = "tgw".
# TGW is owned by the central/network account and shared to workload accounts via RAM.
# Monthly cost: ~$36/attachment. Use only when peering management overhead > TGW cost.

resource "aws_ec2_transit_gateway" "main" {
  count = var.connectivity_mode == "tgw" ? 1 : 0

  description                     = "${local.name_prefix} Transit Gateway for workload connectivity"
  amazon_side_asn                 = 64512
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = merge(local.full_tags, { Name = "${local.name_prefix}-tgw" })
}

# Central VPC attachment to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "central" {
  count = var.connectivity_mode == "tgw" ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.main[0].id
  vpc_id             = var.central_vpc_id
  subnet_ids         = data.terraform_remote_state.eks.outputs.active_private_subnets

  tags = merge(local.full_tags, { Name = "${local.name_prefix}-central-attachment" })
}

# RAM share — shares TGW to workload accounts (if different accounts)
# Workload accounts then create their own VPC attachments via aj-infra-release
resource "aws_ram_resource_share" "tgw" {
  count = var.connectivity_mode == "tgw" ? 1 : 0

  name                      = "${local.name_prefix}-tgw-share"
  allow_external_principals = false

  tags = local.full_tags
}

resource "aws_ram_resource_association" "tgw" {
  count = var.connectivity_mode == "tgw" ? 1 : 0

  resource_arn       = aws_ec2_transit_gateway.main[0].arn
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}
