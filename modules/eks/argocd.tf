resource "argocd_cluster" "this" {
  count = var.reg-cluster-in-argocd ? 1 : 0

  server = module.eks.cluster_endpoint
  name   = module.eks.cluster_name

  config {
    aws_auth_config {
      cluster_name = module.eks.cluster_name
      role_arn     = var.argocd_deployer_role_arn
    }
    tls_client_config {
      ca_data = base64decode(module.eks.cluster_certificate_authority_data)
    }
  }
}

locals {
  default_admin_role = {
    name = "${var.name}-admin-role"
    policies = [
      "p, proj:${var.name}:${var.name}-admin-role, applications, *, ${var.name}/*, allow"
    ]
    groups = var.argocd_project_mapping_oidc_admin
  }

  default_dev_role = {
    name = "${var.name}-dev-role"
    policies = [
      "p, proj:${var.name}:${var.name}-dev-role, applications, *, ${var.name}/*, allow"
    ]
    groups = var.argocd_project_mapping_oidc_dev
  }

  roles = concat(
    length(var.argocd_project_mapping_oidc_admin) > 0 ? [local.default_admin_role] : [],
    length(var.argocd_project_mapping_oidc_dev) > 0 ? [local.default_dev_role] : [],
    length(var.argocd_extra_roles) > 0 ? var.argocd_extra_roles : [],
  )
}

resource "argocd_project" "this" {
  count = var.reg-cluster-in-argocd ? 1 : 0

  metadata {
    name      = var.name
    namespace = "argo-cd"
  }

  spec {
    source_repos      = ["*"]
    source_namespaces = ["*"]

    cluster_resource_whitelist {
      group = "*"
      kind  = "*"
    }

    namespace_resource_whitelist {
      group = "*"
      kind  = "*"
    }

    destination {
      name      = argocd_cluster.this[0].name
      namespace = "*"
    }

    dynamic "role" {
      for_each = local.roles
      content {
        name     = role.value.name
        policies = role.value.policies
        groups   = role.value.groups
      }
    }
  }
}