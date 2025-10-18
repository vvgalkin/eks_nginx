terraform {}

provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

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

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"

  cluster_name    = var.name
  cluster_version = var.cluster_version

  vpc_id     = local.vpc_id
  subnet_ids = concat(local.private_subnets, local.public_subnets)

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  eks_managed_node_groups = {
    "${var.anchor_node_group_name}" = {
      min_size     = var.anchor_min_size
      desired_size = var.anchor_desired_size
      max_size     = var.anchor_max_size

      instance_types = var.anchor_instance_types
      subnet_ids     = local.private_subnets
      labels         = var.anchor_node_labels
      taints         = var.anchor_node_taints
    }
  }

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
  }

  authentication_mode                      = var.authentication_mode
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

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

data "aws_eks_cluster" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--region", var.region, "--cluster-name", module.eks.cluster_name]
    }
  }
}

resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name       = var.metrics_server_name
  namespace  = var.metrics_server_namespace
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

  timeout         = var.metrics_server_timeout
  wait            = true
  cleanup_on_fail = true
}

module "alb_irsa" {
  count   = var.enable_alb_controller ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix                       = "ALB-${var.name}"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${var.alb_controller_namespace}:${var.alb_controller_service_account_name}"]
    }
  }

  tags = var.tags

  depends_on = [module.eks]
}

resource "helm_release" "alb" {
  count = var.enable_alb_controller ? 1 : 0

  name       = var.alb_controller_name
  namespace  = var.alb_controller_namespace
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_chart_version

  values = concat([
    yamlencode({
      clusterName = module.eks.cluster_name
      serviceAccount = {
        create = true
        name   = var.alb_controller_service_account_name
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

  timeout         = var.alb_controller_timeout
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true
}

resource "time_sleep" "wait_for_alb_webhook" {
  count           = var.enable_alb_controller ? 1 : 0
  create_duration = "60s"

  depends_on = [helm_release.alb]
}

resource "aws_iam_policy" "karpenter_controller_instance_profile" {
  count       = var.enable_karpenter ? 1 : 0
  name        = "KarpenterControllerInstanceProfile-${var.name}"
  description = "Extra permissions for Karpenter 1.8 to manage/list IAM Instance Profiles"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
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
  count      = var.enable_karpenter ? 1 : 0
  role       = module.karpenter[0].iam_role_name
  policy_arn = aws_iam_policy.karpenter_controller_instance_profile[0].arn
}

module "karpenter" {
  count   = var.enable_karpenter ? 1 : 0
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.24.0"

  cluster_name = module.eks.cluster_name
  namespace    = var.karpenter_namespace

  enable_irsa              = true
  irsa_oidc_provider_arn   = module.eks.oidc_provider_arn
  iam_role_name            = "karpenter-controller-${var.name}"
  iam_role_use_name_prefix = false

  create_node_iam_role          = true
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "karpenter-node-${var.name}"
  node_iam_role_additional_policies = var.karpenter_node_additional_policies

  enable_v1_permissions = true

  tags = var.tags

  depends_on = [module.eks]
}

resource "helm_release" "karpenter_crd" {
  count            = var.enable_karpenter ? 1 : 0
  name             = "karpenter-crd"
  namespace        = var.karpenter_namespace
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
  timeout         = var.karpenter_timeout_crd
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
  namespace  = var.karpenter_namespace
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_chart_version

  values = concat([
    yamlencode({
      replicaCount       = var.karpenter_replicas
      postInstallHook    = { enabled = false }
      dnsPolicy          = var.karpenter_dns_policy
      priorityClassName  = var.karpenter_priority_class
      podDisruptionBudget = { enabled = true, minAvailable = 1 }
      controller = {
        env = [
          {
            name = "FEATURE_GATES"
            value = join(",", [
              for k, v in var.karpenter_feature_gates :
              "${replace(title(replace(k, "_", " ")), " ", "")}=${v}"
            ])
          }
        ]
        resources = var.karpenter_resources
      }
      settings = {
        clusterName       = module.eks.cluster_name
        clusterEndpoint   = module.eks.cluster_endpoint
        interruptionQueue = module.karpenter[0].queue_name
      }
      serviceAccount = {
        create = true
        name   = var.karpenter_service_account_name
        annotations = {
          "eks.amazonaws.com/role-arn" = module.karpenter[0].iam_role_arn
        }
      }
    })
  ], [for v in var.karpenter_helm_extra_values : yamlencode(v)])

  atomic          = true
  cleanup_on_fail = true
  timeout         = var.karpenter_timeout_controller
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

resource "time_sleep" "wait_for_karpenter" {
  count           = var.enable_karpenter ? 1 : 0
  create_duration = "30s"
  depends_on      = [helm_release.karpenter]
}

resource "helm_release" "karpenter_resources" {
  count     = var.enable_karpenter ? 1 : 0
  name      = "karpenter-resources"
  namespace = var.karpenter_namespace
  chart     = "${path.module}/charts/karpenter-resources"

  disable_openapi_validation = true
  depends_on = [
    helm_release.karpenter_crd,
    helm_release.karpenter,
    time_sleep.wait_for_karpenter
  ]

  values = [
    yamlencode({
      clusterName    = module.eks.cluster_name
      roleName       = module.karpenter[0].node_iam_role_name
      clusterVersion = var.cluster_version
      ec2NodeClass = {
        name      = var.karpenter_ec2nodeclass_name
        amiFamily = var.karpenter_ami_family
        amiAlias = var.karpenter_ami_alias != null ? var.karpenter_ami_alias : (
          var.karpenter_ami_family == "AL2023" ? "al2023@latest" : (
            var.karpenter_ami_family == "AL2" ? "al2@latest" : (
              var.karpenter_ami_family == "Bottlerocket" ? "bottlerocket@latest" : "al2023@latest"
            )
          )
        )
        tags                = var.karpenter_ec2nodeclass_tags
        blockDeviceMappings = var.karpenter_block_device_mappings
      }
      nodePool = {
        name                = var.karpenter_nodepool_name
        labels              = var.karpenter_nodepool_labels
        instanceFamilies    = var.karpenter_instance_families
        capacityTypes       = var.karpenter_capacity_types
        consolidationPolicy = var.karpenter_consolidation_policy
        consolidateAfter    = var.karpenter_consolidate_after
        expireAfter         = var.karpenter_expire_after
        cpuLimit            = var.karpenter_nodepool_cpu_limit
        memoryLimit         = var.karpenter_nodepool_memory_limit
        weight              = var.karpenter_nodepool_weight
      }
    })
  ]

  atomic          = true
  cleanup_on_fail = true
  timeout         = var.karpenter_timeout_resources
  wait_for_jobs   = true
}

resource "aws_ec2_tag" "karpenter_discovery_sg" {
  count       = var.enable_karpenter ? 1 : 0
  resource_id = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = module.eks.cluster_name

  depends_on = [module.eks]
}

resource "helm_release" "nginx" {
  count     = var.enable_nginx ? 1 : 0
  name      = var.nginx_name
  namespace = var.nginx_namespace
  chart     = "${path.module}/charts/nginx"

  values = [
    yamlencode({
      deploymentName = var.nginx_deployment_name
      image          = var.nginx_image
      replicas       = var.nginx_replicas
      resources      = var.nginx_resources
      hpa = {
        minReplicas      = var.nginx_hpa_min_replicas
        maxReplicas      = var.nginx_hpa_max_replicas
        targetCPUPercent = var.nginx_hpa_target_cpu_percent
      }
      ingress = {
        class      = var.nginx_ingress_class
        albScheme  = var.nginx_alb_scheme
        targetType = var.nginx_alb_target_type
      }
    })
  ]

  depends_on = [
    module.eks,
    helm_release.alb,
    time_sleep.wait_for_alb_webhook,
    helm_release.metrics_server
  ]

  timeout = var.nginx_timeout
  wait    = true
}

resource "null_resource" "cleanup_nginx" {
  count = var.enable_nginx ? 1 : 0

  triggers = {
    nginx_enabled = var.enable_nginx
    delay         = var.cleanup_delay_nginx
  }

  depends_on = [helm_release.nginx]

  provisioner "local-exec" {
    when    = destroy
    command = "echo '[1/6] Cleaning up Nginx and ALB resources...' && sleep ${self.triggers.delay}"
  }
}

resource "null_resource" "cleanup_karpenter_resources" {
  count = var.enable_karpenter ? 1 : 0

  triggers = {
    karpenter_enabled = var.enable_karpenter
    delay             = var.cleanup_delay_karpenter_resources
  }

  depends_on = [
    helm_release.karpenter_resources,
    null_resource.cleanup_nginx
  ]

  provisioner "local-exec" {
    when    = destroy
    command = "echo '[2/6] Cleaning up Karpenter NodePools and draining nodes...' && sleep ${self.triggers.delay}"
  }
}

resource "null_resource" "cleanup_karpenter_controller" {
  count = var.enable_karpenter ? 1 : 0

  triggers = {
    karpenter_enabled = var.enable_karpenter
    delay             = var.cleanup_delay_karpenter_controller
  }

  depends_on = [
    helm_release.karpenter,
    null_resource.cleanup_karpenter_resources
  ]

  provisioner "local-exec" {
    when    = destroy
    command = "echo '[3/6] Cleaning up Karpenter Controller...' && sleep ${self.triggers.delay}"
  }
}

resource "null_resource" "cleanup_controllers" {
  count = var.enable_karpenter || var.enable_alb_controller ? 1 : 0

  triggers = {
    karpenter_enabled = var.enable_karpenter
    alb_enabled       = var.enable_alb_controller
    delay             = var.cleanup_delay_controllers
  }

  depends_on = [
    helm_release.karpenter_crd,
    helm_release.alb,
    null_resource.cleanup_karpenter_controller
  ]

  provisioner "local-exec" {
    when    = destroy
    command = "echo '[4/6] Cleaning up Karpenter CRDs and ALB Controller...' && sleep ${self.triggers.delay}"
  }
}

resource "null_resource" "cleanup_metrics" {
  count = var.enable_metrics_server ? 1 : 0

  triggers = {
    metrics_enabled = var.enable_metrics_server
    delay           = var.cleanup_delay_metrics
  }

  depends_on = [
    helm_release.metrics_server,
    null_resource.cleanup_controllers
  ]

  provisioner "local-exec" {
    when    = destroy
    command = "echo '[5/6] Cleaning up Metrics Server and waiting for ENI cleanup...' && sleep ${self.triggers.delay}"
  }
}

resource "null_resource" "cleanup_final" {
  triggers = {
    vpc_id       = local.vpc_id
    cluster_name = module.eks.cluster_name
    delay        = var.cleanup_delay_final
  }

  depends_on = [
    module.eks,
    null_resource.cleanup_nginx,
    null_resource.cleanup_karpenter_resources,
    null_resource.cleanup_karpenter_controller,
    null_resource.cleanup_controllers,
    null_resource.cleanup_metrics
  ]

  provisioner "local-exec" {
    when    = destroy
    command = "echo '[6/6] Final cleanup before destroying EKS and VPC...' && sleep ${self.triggers.delay}"
  }
}