# ── Cilium — the hub's CNI ────────────────────────────────────────────────────
# WITHOUT THIS THE HUB HAS NO POD NETWORKING AT ALL.
#
# envs/central/<class>/<tier>/eks.tfvars sets `cni = "cilium"`, and
# aj-tf-module-eks then deliberately STRIPS the vpc-cni and kube-proxy addons —
# "Cilium's eBPF replaces both" (its locals.tf). The module does not install
# Cilium; it only emits `cilium_helm_values` for someone else to consume.
#
# On workload clusters that someone is aj-infra-platform. The central hubs have
# no platform layer — `platform_module_tag` exists only under `clusters:` in
# versions.yaml, and the hub env dirs have no platform.tfvars — so nothing
# installed a CNI on them. The hub would have come up with nodes NotReady, no
# pod networking, and an ArgoCD that never starts.
#
# ── Why this is Terraform and not an ApplicationSet ───────────────────────────
# ArgoCD cannot deploy the CNI it needs in order to run. Cilium has to exist
# before any pod that is not host-networked can schedule, which includes every
# ArgoCD component. The ordering is: EKS → Cilium → ArgoCD → everything ArgoCD
# manages. `helm_release.argocd` depends on this explicitly rather than relying
# on Terraform's graph, because nothing else forces the edge.
#
# Cilium itself bootstraps because the agent DaemonSet is hostNetwork — it does
# not need a CNI to schedule, which is what makes this order possible at all.
#
# ── Values ────────────────────────────────────────────────────────────────────
# The settings come from the EKS module's output, through remote state. They are
# a FLAT map of dotted keys ("ipam.mode", "kubeProxyReplacement", ...), so they
# are passed as `set` blocks — helm path-expands those. The module's own usage
# comment suggests `helm install -f <(terraform output -json cilium_helm_values)`
# and that is wrong: a values FILE does not path-expand dotted keys, so every
# one of them would land as a literal top-level key and Cilium would install on
# defaults — no tunnel, no pod CIDR, no kube-proxy replacement. Reported as
# aj-tf-module-eks#TBD.

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.chart_version_cilium
  namespace  = "kube-system"

  # Every key the EKS module computed for this cluster: routing mode, pod CIDR,
  # kube-proxy replacement, the API server endpoint, WireGuard encryption.
  dynamic "set" {
    for_each = data.terraform_remote_state.eks.outputs.cilium_helm_values
    content {
      name  = set.key
      value = set.value
    }
  }

  # Hub-specific additions on top of those. Kept in a file rather than inline so
  # the same values can be rendered offline by aj-gitops's platform-dry-run.
  values = [
    file("${path.module}/helm-values/cilium/${var.central_class}-${var.central_tier}.yaml")
  ]

  wait    = true
  timeout = 600
}
