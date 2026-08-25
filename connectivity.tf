# ── Central ↔ Workload VPC Connectivity — Transit Gateway (optional) ─────────
# Central↔workload VPC peering is owned by aj-infra-networking/peering.tf, not
# here — see CLAUDE.md "Central Cluster Connectivity" for the full history of why
# (this repo, aj-infra-release, and aj-infra-networking all independently
# implemented the same peering connections; consolidated into aj-infra-networking
# on 2026-08-24, since it's the dedicated network-topology repo with the more
# complete isolation model).
#
# What remains here is ONLY the Transit Gateway option, since nothing else in the
# org implements TGW. It stays off (create_tgw = false) until the org crosses the
# documented trigger (10+ VPC pairs, or on-prem/cross-region expansion) — at that
# point this should also move to aj-infra-networking for consistency, matching its
# "Switching to TGW" section, but isn't a live conflict today so left as-is.
#
# Monthly cost when enabled: ~$36/attachment. Use only when peering management
# overhead > TGW cost.

resource "aws_ec2_transit_gateway" "main" {
  count = var.create_tgw ? 1 : 0

  description                     = "${local.name_prefix} Transit Gateway for workload connectivity"
  amazon_side_asn                 = 64512
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = merge(local.full_tags, { Name = "${local.name_prefix}-tgw" })
}

# Central VPC attachment to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "central" {
  count = var.create_tgw ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.main[0].id
  vpc_id             = var.central_vpc_id
  subnet_ids         = data.terraform_remote_state.eks.outputs.active_private_subnets

  tags = merge(local.full_tags, { Name = "${local.name_prefix}-central-attachment" })
}

# RAM share — shares TGW to workload accounts (if different accounts)
# Workload accounts then create their own VPC attachments via aj-infra-release
resource "aws_ram_resource_share" "tgw" {
  count = var.create_tgw ? 1 : 0

  name                      = "${local.name_prefix}-tgw-share"
  allow_external_principals = false

  tags = local.full_tags
}

resource "aws_ram_resource_association" "tgw" {
  count = var.create_tgw ? 1 : 0

  resource_arn       = aws_ec2_transit_gateway.main[0].arn
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}
