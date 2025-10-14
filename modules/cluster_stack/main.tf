terraform {
  required_version = ">= 1.6.0"

  backend "local" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.55"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
  }
}

########################################
# Providers
########################################
provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

########################################
# Networking (always create VPC)
########################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "${var.name}-vpc"
  cidr = var.vpc_cidr
  azs  = var.azs

  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  # Required tags for ALB & Karpenter discoverability
  private_subnet_tags = {
    "kubernetes.io/cluster/${var.name}" = "shared"
    "kubernetes.io/role/internal-elb"   = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.name}" = "shared"
    "kubernetes.io/role/elb"            = "1"
  }

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = var.tags
}

locals {
  vpc_id_out          = module.vpc.vpc_id
  private_subnets_out = module.vpc.private_subnets
  public_subnets_out  = module.vpc.public_subnets
}

########################################
# EKS (anchor MNG; core addons)
########################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"

  cluster_name    = var.name
  cluster_version = var.cluster_version

  vpc_id     = local.vpc_id_out
  subnet_ids = concat(local.private_subnets_out, local.public_subnets_out)

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Minimal anchor nodegroup for system pods
  eks_managed_node_groups = {
    core = {
      min_size     = var.anchor_min_size
      desired_size = var.anchor_desired_size
      max_size     = var.anchor_max_size

      instance_types = var.anchor_instance_types
      subnet_ids     = local.private_subnets_out
      labels         = { role = "core" }
    }
  }



  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
  }
  # включаем современную аутентификацию EKS через переменную модуля
  authentication_mode = "API_AND_CONFIG_MAP"

  # выдаём кластерный admin-доступ всем ролям из var.admin_role_arns
  access_entries = {
    for arn in var.admin_role_arns :
    "admin-${reverse(split("/", arn))[0]}" => {
      principal_arn     = arn
      kubernetes_groups = [] # не обязательно при использовании managed policies

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
}

########################################
# Data for k8s/helm providers
########################################
data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name

  # Ждём создания кластера
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name

  # Ждём создания кластера
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

########################################
# AWS Load Balancer Controller (optional)
########################################
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
}

resource "helm_release" "alb" {
  count      = var.enable_alb_controller ? 1 : 0
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_chart_version

  values = concat(
    [
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
    ],
    [for v in var.alb_controller_extra_values : yamlencode(v)]
  )

  depends_on = [module.alb_irsa]
}

########################################
# metrics-server (optional)
########################################
resource "helm_release" "metrics_server" {
  count      = var.enable_metrics_server ? 1 : 0
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version

  # Для теста упрощаем TLS; в проде убрать через overrides
  values = concat(
    [
      yamlencode({
        args = ["--kubelet-insecure-tls"]
      })
    ],
    [for v in var.metrics_server_extra_values : yamlencode(v)]
  )
}

#####################################
# Karpenter (20.24.0)
#####################################
module "karpenter" {
  count   = var.enable_karpenter ? 1 : 0
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.24.0"

  # базовое
  cluster_name = module.eks.cluster_name
  namespace    = "karpenter"

  # IAM для контроллера (IRSA)
  enable_irsa              = true
  irsa_oidc_provider_arn   = module.eks.oidc_provider_arn
  iam_role_name            = "karpenter-controller-${var.name}"
  iam_role_use_name_prefix = false

  # IAM для нод, которые создаст Karpenter
  create_node_iam_role              = true
  node_iam_role_use_name_prefix     = false
  node_iam_role_name                = "karpenter-node-${var.name}"
  node_iam_role_additional_policies = var.karpenter_node_additional_policies

  # Рекомендуется для свежих кластеров
  enable_v1_permissions = true

  # Если будете переиспользовать роль MNG — ставьте false, чтобы не словить 409
  # create_access_entry          = true

  # Очередь для interruption events модуль создаёт сам; можно явно включить:
  # create_sqs_queue            = true

  tags = var.tags
}

# CRDs
resource "helm_release" "karpenter_crd" {
  count            = var.enable_karpenter ? 1 : 0
  name             = "karpenter-crd"
  namespace        = "karpenter"
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  version          = var.karpenter_crd_version
}

# Контроллер
resource "helm_release" "karpenter" {
  count      = var.enable_karpenter ? 1 : 0
  name       = "karpenter"
  namespace  = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_chart_version

  # Важно: ждём и CRD, и IAM/SQS от module.karpenter
  depends_on = [
    helm_release.karpenter_crd,
    module.karpenter
  ]

  values = concat(
    [
      yamlencode({
        dnsPolicy = "Default"
        settings = {
          clusterName       = module.eks.cluster_name
          clusterEndpoint   = module.eks.cluster_endpoint
          interruptionQueue = module.karpenter[0].queue_name
        }
        serviceAccount = {
          annotations = {
            "eks.amazonaws.com/role-arn" = module.karpenter[0].iam_role_arn
          }
        }
      })
    ],
    [for v in var.karpenter_helm_extra_values : yamlencode(v)]
  )
}
