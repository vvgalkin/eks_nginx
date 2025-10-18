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
  single_nat_gateway   = true
  
  cluster_version = "1.29"
  
  anchor_instance_types = ["t3.medium"]
  anchor_min_size       = 1
  anchor_desired_size   = 1
  anchor_max_size       = 2
  
  enable_alb_controller = true
  enable_metrics_server = true
  enable_karpenter      = true
  enable_nginx          = true
  
  alb_controller_chart_version = "1.9.2"
  metrics_server_chart_version = "3.12.1"
  karpenter_chart_version      = "1.8.1"
  karpenter_crd_version        = "1.8.1"
  
  metrics_server_insecure_tls = true
  
  karpenter_ami_family = "AL2023"
  karpenter_ami_alias  = null
  
  karpenter_node_additional_policies = {
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }
  
  alb_controller_extra_values = [
    {
      enableIngressClassParams = false
    }
  ]
  metrics_server_extra_values = []
  karpenter_helm_extra_values = []
  
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

terraform {
  source = "./modules/cluster_stack"
}

inputs = {
  region  = local.region
  name    = local.name
  tags    = local.tags
  
  vpc_cidr             = local.vpc_cidr
  azs                  = local.azs
  private_subnet_cidrs = local.private_subnet_cidrs
  public_subnet_cidrs  = local.public_subnet_cidrs
  single_nat_gateway   = local.single_nat_gateway
  
  cluster_version = local.cluster_version
  
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
  karpenter_crd_version        = local.karpenter_crd_version
  
  metrics_server_insecure_tls = local.metrics_server_insecure_tls
  
  karpenter_ami_family                = local.karpenter_ami_family
  karpenter_ami_alias                 = local.karpenter_ami_alias
  karpenter_node_additional_policies  = local.karpenter_node_additional_policies
  
  alb_controller_extra_values = local.alb_controller_extra_values
  metrics_server_extra_values = local.metrics_server_extra_values
  karpenter_helm_extra_values = local.karpenter_helm_extra_values
  
  admin_role_arns = local.admin_role_arns
}