# ==========================
# modules/cluster_stack/main.tf (UPDATED)
# ==========================

terraform {}

provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

###########################################
# VPC Module
###########################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "${var.name}-vpc"
  cidr = var.vpc_cidr
  azs  = var.azs

  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.name}" = "shared"
    "kubernetes.io/role/internal-elb"   = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.name}" = "shared"
    "kubernetes.io/role/elb"            = "1"
  }

  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  tags = var.tags
}

locals {
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  public_subnets  = module.vpc.public_subnets
}

###########################################
# EKS Cluster
###########################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"

  cluster_name    = var.name
  cluster_version = var.cluster_version

  vpc_id     = local.vpc_id
  subnet_ids = concat(local.private_subnets, local.public_subnets)

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    core = {
      min_size     = var.anchor_min_size
      desired_size = var.anchor_desired_size
      max_size     = var.anchor_max_size

      instance_types = var.anchor_instance_types
      subnet_ids     = local.private_subnets
      labels         = { role = "core" }
    }
  }

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
  }

  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    for idx, arn in var.admin_role_arns :
    "admin-${idx}" => {
      principal_arn = arn

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = var.tags

  depends_on = [module.vpc]
}

###########################################
# EKS Cluster Auth Data
###########################################
data "aws_eks_cluster" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

###########################################
# Helm Provider Configuration
###########################################
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks","get-token","--region",var.region,"--cluster-name",module.eks.cluster_name]
    }
  }
}

###########################################
# Metrics Server
###########################################
resource "helm_release" "metrics_server" {
  count      = var.enable_metrics_server ? 1 : 0
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version

  values = concat(
    var.metrics_server_insecure_tls ? [
      yamlencode({ args = ["--kubelet-insecure-tls"] })
    ] : [],
    [for v in var.metrics_server_extra_values : yamlencode(v)]
  )

  depends_on = [module.eks]

  timeout         = 300
  wait            = true
  cleanup_on_fail = true
}

###########################################
# AWS Load Balancer Controller
###########################################
module "alb_irsa" {
  count   = var.enable_alb_controller ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix                       = "ALB-${var.name}"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.tags

  depends_on = [module.eks]
}

resource "helm_release" "alb" {
  count      = var.enable_alb_controller ? 1 : 0
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_chart_version

  values = concat([
    yamlencode({
      clusterName = module.eks.cluster_name
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.alb_irsa[0].iam_role_arn
        }
      }
    })
  ], [for v in var.alb_controller_extra_values : yamlencode(v)])

  depends_on = [
    module.eks,
    module.alb_irsa
  ]

  timeout         = 600
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true
}

###########################################
# Karpenter
###########################################
# Extra IAM for Karpenter 1.8 Instance Profiles
resource "aws_iam_policy" "karpenter_controller_instance_profile" {
  name        = "KarpenterControllerInstanceProfile-${var.name}"
  description = "Extra permissions for Karpenter 1.8 to manage/list IAM Instance Profiles"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:ListInstanceProfiles"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_instance_profile" {
  role       = module.karpenter[0].iam_role_name
  policy_arn = aws_iam_policy.karpenter_controller_instance_profile.arn
}

module "karpenter" {
  count   = var.enable_karpenter ? 1 : 0
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.24.0"

  cluster_name = module.eks.cluster_name
  namespace    = "karpenter"

  enable_irsa              = true
  irsa_oidc_provider_arn   = module.eks.oidc_provider_arn
  iam_role_name            = "karpenter-controller-${var.name}"
  iam_role_use_name_prefix = false

  create_node_iam_role              = true
  node_iam_role_use_name_prefix     = false
  node_iam_role_name                = "karpenter-node-${var.name}"
  node_iam_role_additional_policies = var.karpenter_node_additional_policies

  enable_v1_permissions = true

  tags = var.tags

  depends_on = [module.eks]
}

resource "helm_release" "karpenter_crd" {
  count            = var.enable_karpenter ? 1 : 0
  name             = "karpenter-crd"
  namespace        = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  version          = var.karpenter_crd_version
  create_namespace = true
  wait             = true

  depends_on = [
    module.eks,
    module.karpenter
  ]

  atomic          = true
  cleanup_on_fail = true
  timeout         = 600
  wait_for_jobs   = true
}

resource "time_sleep" "wait_before_karpenter" {
  count           = var.enable_karpenter ? 1 : 0
  depends_on      = [helm_release.karpenter_crd]
  create_duration = "60s"
}

resource "helm_release" "karpenter" {
  count      = var.enable_karpenter ? 1 : 0
  name       = "karpenter"
  namespace  = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_chart_version

  values = concat([
    yamlencode({
      replicaCount    = 1
      postInstallHook = { enabled = false }
      dnsPolicy       = "Default"
      priorityClassName = "system-cluster-critical"
      podDisruptionBudget = { enabled = true, minAvailable = 1 }
      controller = {
        env = [
          { name = "FEATURE_GATES", value = "ReservedCapacity=true,SpotToSpotConsolidation=false,NodeRepair=false,NodeOverlay=false,StaticCapacity=false" }
        ]
        resources = {
          requests = { cpu = "200m", memory = "256Mi" }
          limits   = { cpu = "1",    memory = "512Mi" }
        }
      }
      settings = {
        clusterName       = module.eks.cluster_name
        clusterEndpoint   = module.eks.cluster_endpoint
        interruptionQueue = module.karpenter[0].queue_name
      }
      serviceAccount = {
        create = true
        name   = "karpenter"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.karpenter[0].iam_role_arn
        }
      }
    })
  ], [for v in var.karpenter_helm_extra_values : yamlencode(v)])

  atomic          = true
  cleanup_on_fail = true
  timeout         = 900
  wait            = true
  wait_for_jobs   = true
  max_history     = 5

  depends_on = [
    module.eks,
    module.karpenter,
    helm_release.karpenter_crd,
    time_sleep.wait_before_karpenter
  ]
}

# NOTE: Removed non-existent helm_release.karpenter_provider_aws
# and adjusted the sequencing below accordingly.

resource "time_sleep" "wait_for_karpenter" {
  count           = var.enable_karpenter ? 1 : 0
  create_duration = "30s"
  depends_on      = [helm_release.karpenter]
}

resource "helm_release" "karpenter_resources" {
  count     = var.enable_karpenter ? 1 : 0
  name      = "karpenter-resources"
  namespace = "karpenter"
  chart     = "${path.module}/charts/karpenter-resources"

  disable_openapi_validation = true
  depends_on = [
    helm_release.karpenter_crd,
    helm_release.karpenter,
    time_sleep.wait_for_karpenter
  ]

  values = [
    yamlencode({
      clusterName   = module.eks.cluster_name
      roleName      = module.karpenter[0].node_iam_role_name
      clusterVersion = var.cluster_version
      ec2NodeClass  = {
        name      = "default-ec2"
        amiFamily = "AL2023"  # <-- use EKS-recommended AL2023 AMIs via SSM resolver; do not set amiSelectorTerms for this
      }
    })
  ]

  atomic          = true
  cleanup_on_fail = true
  timeout         = 600
  wait_for_jobs   = true
}

# # Кластер уже есть, берём его SG
# data "aws_eks_cluster" "this" {
#   name       = module.eks.cluster_name
#   depends_on = [module.eks]
# }

# Проставляем discovery-тег, чтобы Karpenter всегда находил SG
resource "aws_ec2_tag" "karpenter_discovery_sg" {
  resource_id = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = module.eks.cluster_name

  depends_on = [module.eks]
}

###########################################
# Nginx Demo Application
###########################################
resource "helm_release" "nginx" {
  count     = var.enable_nginx ? 1 : 0
  name      = "nginx-demo"
  namespace = "default"
  chart     = "${path.module}/charts/nginx"

  depends_on = [
    module.eks,
    helm_release.alb,
    helm_release.metrics_server
  ]

  timeout = 300
  wait    = true
}

###########################################
# Null Resources for destroy ordering (UPDATED)
###########################################

resource "null_resource" "cleanup_nginx" {
  depends_on = [helm_release.nginx]
  provisioner "local-exec" {
    when    = destroy
    command = "echo '[1/6] Cleaning up Nginx and ALB resources...' && sleep 45"
  }
}

resource "null_resource" "cleanup_karpenter_resources" {
  depends_on = [null_resource.cleanup_nginx, helm_release.karpenter_resources]
  provisioner "local-exec" {
    when    = destroy
    command = "echo '[2/6] Cleaning up Karpenter NodePools and draining nodes...' && sleep 30"
  }
}

# Removed step for karpenter_provider_aws

resource "null_resource" "cleanup_karpenter_controller" {
  depends_on = [null_resource.cleanup_karpenter_resources, helm_release.karpenter]
  provisioner "local-exec" {
    when    = destroy
    command = "echo '[3/6] Cleaning up Karpenter Controller...' && sleep 10"
  }
}

resource "null_resource" "cleanup_controllers" {
  depends_on = [null_resource.cleanup_karpenter_controller, helm_release.karpenter_crd, helm_release.alb]
  provisioner "local-exec" {
    when    = destroy
    command = "echo '[4/6] Cleaning up Karpenter CRDs and ALB Controller...' && sleep 30"
  }
}

resource "null_resource" "cleanup_metrics" {
  depends_on = [null_resource.cleanup_controllers, helm_release.metrics_server]
  provisioner "local-exec" {
    when    = destroy
    command = "echo '[5/6] Cleaning up Metrics Server and waiting for ENI cleanup...' && sleep 60"
  }
}

resource "null_resource" "cleanup_final" {
  depends_on = [null_resource.cleanup_metrics, module.eks]
  triggers = { vpc_id = local.vpc_id }
  provisioner "local-exec" {
    when    = destroy
    command = "echo '[6/6] Final cleanup before destroying EKS and VPC...' && sleep 30"
  }
}
