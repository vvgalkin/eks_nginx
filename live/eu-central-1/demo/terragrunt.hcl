include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/cluster_stack"
}

locals {
  region          = "eu-central-1"
  cluster_version = "1.29"

  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  anchor_instance_types = ["t3.medium"]
  anchor_min_size       = 1
  anchor_desired_size   = 1
  anchor_max_size       = 2

  enable_alb_controller = true
  enable_metrics_server = true
  enable_karpenter      = true
  enable_nginx          = true

  alb_controller_chart_version = "1.8.1"
  metrics_server_chart_version = "3.12.1"
  karpenter_chart_version      = "0.36.0"
}

inputs = {
  cluster_version = local.cluster_version

  vpc_cidr             = local.vpc_cidr
  azs                  = local.azs
  private_subnet_cidrs = local.private_subnet_cidrs
  public_subnet_cidrs  = local.public_subnet_cidrs

  anchor_instance_types = local.anchor_instance_types
  anchor_min_size       = local.anchor_min_size
  anchor_desired_size   = local.anchor_desired_size
  anchor_max_size       = local.anchor_max_size

  enable_alb_controller = local.enable_alb_controller
  enable_metrics_server = local.enable_metrics_server
  enable_karpenter      = local.enable_karpenter
  enable_nginx          = local.enable_nginx

  alb_controller_chart_version = local.alb_controller_chart_version
  metrics_server_chart_version = local.metrics_server_chart_version
  karpenter_chart_version      = local.karpenter_chart_version
}