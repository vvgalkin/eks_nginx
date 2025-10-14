terraform {
  source = "./modules/cluster_stack"
}

locals {
  environment = "demo"
  region      = "eu-central-1"
  
  # Сеть
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  # EKS
  cluster_version       = "1.29"
  anchor_instance_types = ["t3.medium"]
  anchor_min            = 1
  anchor_desired        = 1
  anchor_max            = 2
  
  # Аддоны
  enable_alb_controller = true
  enable_metrics_server = true
  enable_karpenter      = true
  enable_nginx          = true
  
  # Версии чартов
  alb_chart_version       = "1.8.1"
  metrics_chart_version   = "3.12.1"
  karpenter_chart_version = "0.36.0"
  karpenter_crd_version   = "0.36.0"
  
  # ✅ ИСПРАВЛЕНО: Правильный способ получить ARN текущего пользователя
  # Можно также использовать роли для лучшей безопасности
  admin_principals = [
    "arn:aws:iam::173517262230:user/Stan",
    # Добавьте роли для CI/CD:
    # "arn:aws:iam::173517262230:role/GithubActionsRole",
  ]
    # Общие теги для всех ресурсов
  common_tags = {
    Project     = "eks-demo"
    ManagedBy   = "terragrunt"
  }
}

inputs = {
  # Базовые
  region  = local.region
  name    = "demo-eks-${local.region}"
  
  tags = {
    Environment = local.environment
  }
  
  # Сеть
  vpc_cidr             = local.vpc_cidr
  azs                  = local.azs
  private_subnet_cidrs = local.private_subnet_cidrs
  public_subnet_cidrs  = local.public_subnet_cidrs
  
  # ✅ ДОБАВЛЕНО: для прода использовать NAT в каждой AZ
  single_nat_gateway = true  # для demo=true, для prod=false
  
  # Anchor node group
  anchor_instance_types = local.anchor_instance_types
  anchor_min_size       = local.anchor_min
  anchor_desired_size   = local.anchor_desired
  anchor_max_size       = local.anchor_max
  
  # Аддоны
  enable_alb_controller = local.enable_alb_controller
  enable_metrics_server = local.enable_metrics_server
  enable_karpenter      = local.enable_karpenter
  enable_nginx          = local.enable_nginx
  
  # Версии чартов
  alb_controller_chart_version = local.alb_chart_version
  metrics_server_chart_version = local.metrics_chart_version
  karpenter_chart_version      = local.karpenter_chart_version
  karpenter_crd_version        = local.karpenter_crd_version
  
  # ✅ ИСПРАВЛЕНО: Admin доступ в кластер
  admin_principals = local.admin_principals
}

remote_state {
  backend = "local"
  
  config = {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  }  
  # Для прода раскомментировать:
  # backend = "s3"
  # config = {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "${path_relative_to_include()}/terraform.tfstate"
  #   region         = "eu-central-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

