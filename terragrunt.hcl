locals {
  region = "eu-central-1"
  name   = "demo-eks-eu-central-1"

  tags = {
    Project     = "eks-demo"
    Environment = "demo"
    ManagedBy   = "terragrunt"
  }

  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  cluster_version = "1.29"
  anchor_types    = ["t3.medium"]
  anchor_min      = 1
  anchor_desired  = 1
  anchor_max      = 2

  enable_alb_controller = true
  enable_metrics_server = true
  enable_karpenter      = true
  enable_nginx          = true

  alb_chart_version       = "1.8.1"
  metrics_chart_version   = "3.12.1"
  karpenter_chart_version = "0.36.0"
  karpenter_crd_version   = "0.36.0"

  admin_role_arns = []
}

remote_state {
  backend = "local"
  config = {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  }
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "local" {}
}
EOF
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws  = { source = "hashicorp/aws",  version = "~> 5.55" }
    helm = { source = "hashicorp/helm", version = "~> 2.13" }
  }
}
EOF
}

terraform {
  source = "./modules/cluster_stack"
}

inputs = {
  region = local.region
  name   = local.name
  tags   = local.tags

  vpc_cidr             = local.vpc_cidr
  azs                  = local.azs
  private_subnet_cidrs = local.private_subnet_cidrs
  public_subnet_cidrs  = local.public_subnet_cidrs

  anchor_instance_types = local.anchor_types
  anchor_min_size       = local.anchor_min
  anchor_desired_size   = local.anchor_desired
  anchor_max_size       = local.anchor_max

  enable_alb_controller         = local.enable_alb_controller
  enable_metrics_server         = local.enable_metrics_server
  enable_karpenter              = local.enable_karpenter
  enable_nginx                  = local.enable_nginx
  alb_controller_chart_version  = local.alb_chart_version
  metrics_server_chart_version  = local.metrics_chart_version
  karpenter_chart_version       = local.karpenter_chart_version
  karpenter_crd_version         = local.karpenter_crd_version

  admin_role_arns = local.admin_role_arns

  create_deployer_role = true
  deployer_role_name   = "TerraformDeployer"
}
