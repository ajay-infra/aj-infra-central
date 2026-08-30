# ── Keycloak — the identity provider ─────────────────────────────────────────
# Lives HERE, in the central cluster, and not in aj-infra-platform. That
# placement is the whole point, so it is worth stating plainly:
#
#   aj-infra-platform is applied to EVERY workload cluster — dev, staging,
#   prod, prod-regulated, internal-tools, team-a-prod. Keycloak there would
#   mean SIX Keycloaks, and therefore SIX ISSUERS.
#
# Six issuers is the exact failure this entire design exists to prevent, just
# reached from a different direction than realm-per-tenant did. See
# aj-infra-context/arch/gateway-selection.md §4: a prior estate OOM-killed a
# gateway at ~24 issuers, and the rule that came out of it is that ISSUER COUNT
# MUST NOT GROW with anything — not with tenants, and not with clusters.
#
# Central has exactly two environments, nonprod and prod. So: two Keycloaks,
# constant forever. Each workload cluster's OPA trusts exactly ONE issuer — its
# tier's Keycloak — and aj-cluster-baseline/opa/policy-issuers.yaml stays a
# single-entry list.
#
# The nonprod/prod split is deliberate rather than incidental: a dev-issued
# token must not be valid in production.
#
# ── Tenants are organizations, not realms ────────────────────────────────────
# Keycloak 26's Organizations feature (GA) puts tenants inside a SINGLE realm,
# each with its own members and its own federated identity provider. A customer
# bringing their own IdP is brokered, and the token reaching the gateway is
# still Keycloak-issued. Tenant is a CLAIM.
#
# ⚠ PROTOTYPE FIRST. "3 realms per tenant" on the previous estate implies those
# realms encoded something — environments, brands. Whether that survives a
# mapping onto organizations is a modelling question and the open risk. See
# gateway-selection.md §5.
#
# ── Off by default: no database ──────────────────────────────────────────────
# Engine decided — Aurora PostgreSQL, DEDICATED and right-sized (~$117/mo at
# db.t4g.medium, against ~$1,280/mo if the application shape were copied).
# Dedicated because an IdP must not inherit the availability of what it
# protects: if the app database is down and Keycloak shares it, you cannot
# authenticate in order to fix anything. Tracked in aj-infra-context#24.
#
# ⚠ BLOCKING, and unresolved: aj-tf-module-aurora sets enable_iam_auth = true
# per a 2026-03-31 standing decision — 15-minute rotating rds-db:connect tokens,
# never static passwords. Keycloak cannot do that out of the box; its JDBC
# connection is fixed at startup with no refresh mechanism. Either the AWS
# Advanced JDBC Driver goes into the image (a build), or a static password
# arrives via External Secrets as an explicit, recorded exception.
#
# ⚠ INCOMPLETE BY DESIGN. Database connection, hostname, TLS and admin
# bootstrap are NOT set below. The keycloakx chart takes these through
# `command`, `extraEnv` and `database.*`, and keys differ across chart majors.
# Left out rather than guessed — a plausible-but-wrong Helm value passes
# terraform validate and fails at apply. Admin credentials must come from a
# Secret via External Secrets, never a Terraform variable, or they land in state.

resource "helm_release" "keycloak" {
  count = var.install_keycloak ? 1 : 0

  name       = "keycloak"
  repository = "https://codecentric.github.io/helm-charts"
  chart      = "keycloakx"
  version    = var.chart_version_keycloak
  namespace  = "keycloak"

  create_namespace = true

  # Production mode. The chart defaults to a dev-friendly start; this forces the
  # optimized build, which refuses to run without a real database and hostname —
  # failing loudly rather than silently starting on H2 and losing every user on
  # the next restart.
  set {
    name  = "command[0]"
    value = "/opt/keycloak/bin/kc.sh"
  }

  set {
    name  = "command[1]"
    value = "start"
  }

  set {
    name  = "command[2]"
    value = "--optimized"
  }

  # Two replicas in the prod tier. An IdP outage is a total outage — nothing
  # authenticates, including the people trying to fix it.
  set {
    name  = "replicas"
    value = var.central_env == "central-prod" ? "2" : "1"
  }

  set {
    name  = "resources.requests.cpu"
    value = "500m"
  }

  set {
    name  = "resources.requests.memory"
    value = "1Gi"
  }

  set {
    name  = "resources.limits.memory"
    value = "2Gi"
  }

  wait    = true
  timeout = 600
}
