resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.43.1"

  values = [yamlencode({
    autoDiscovery = {
      clusterName = module.eks.cluster_name
    }
    rbac = {
      serviceAccount = {
        create = true
        name   = "cluster-autoscaler"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.cluster_autoscaler_irsa.iam_role_arn
        }
      }
    }
    extraArgs = {
      stderrthreshold                 = "info"
      v                               = "4"
      skip-nodes-with-local-storage   = "false"
      balance-similar-node-groups     = "true"
      expander                        = "least-waste"
    }
  })]

  depends_on = [module.cluster_autoscaler_irsa]
}
