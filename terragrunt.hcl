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
  
  authentication_mode                      = "API_AND_CONFIG_MAP"
  cluster_endpoint_public_access           = true
  cluster_endpoint_private_access          = true
  enable_cluster_creator_admin_permissions = true
  admin_role_arns                          = []

  anchor_node_group_name  = "core"
  anchor_instance_types   = ["t3.medium"]
  anchor_min_size         = 1
  anchor_desired_size     = 1
  anchor_max_size         = 2
  
  anchor_node_labels = {
    role        = "core"
    environment = "demo"
  }
  
  anchor_node_taints = []
  enable_alb_controller = true
  enable_metrics_server = true
  enable_karpenter      = true
  enable_nginx          = true
  
  alb_controller_name                 = "aws-load-balancer-controller"
  alb_controller_namespace            = "kube-system"
  alb_controller_service_account_name = "aws-load-balancer-controller"
  alb_controller_chart_version        = "1.9.2"
  alb_controller_timeout              = 600
  
  alb_controller_extra_values = [
    {
      enableIngressClassParams = false
    }
  ]

  metrics_server_name             = "metrics-server"
  metrics_server_namespace        = "kube-system"
  metrics_server_chart_version    = "3.12.1"
  metrics_server_insecure_tls     = true
  metrics_server_timeout          = 300
  metrics_server_extra_values     = []
  
  karpenter_namespace              = "karpenter"
  karpenter_service_account_name   = "karpenter"
  karpenter_chart_version          = "1.8.1"
  karpenter_crd_version            = "1.8.1"
  karpenter_replicas               = 1
  karpenter_priority_class         = "system-cluster-critical"
  karpenter_dns_policy             = "Default"
  karpenter_timeout_crd            = 1200
  karpenter_timeout_controller     = 1200
  karpenter_timeout_resources      = 1200
  
  karpenter_resources = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1"
      memory = "512Mi"
    }
  }
  
  karpenter_feature_gates = {
    reserved_capacity          = true
    spot_to_spot_consolidation = false
    node_repair                = false
    node_overlay               = false
    static_capacity            = false
  }
  
  karpenter_ami_family = "AL2023"
  karpenter_ami_alias  = "al2023@v20240915"
  
  karpenter_node_additional_policies = {
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }
  
  karpenter_helm_extra_values = []
  
  karpenter_nodepool_name   = "default"
  karpenter_instance_families = ["t3", "t3a", "m6i", "c6i"]
  karpenter_capacity_types    = ["spot", "on-demand"]
  
  karpenter_nodepool_labels = {
    role = "workload"
  }
  
  karpenter_consolidation_policy = "WhenEmptyOrUnderutilized"
  karpenter_consolidate_after    = "1m"
  karpenter_expire_after         = null
  karpenter_nodepool_cpu_limit    = "200"
  karpenter_nodepool_memory_limit = null
  karpenter_nodepool_weight       = 10
  karpenter_ec2nodeclass_name = "default-ec2"
  
  karpenter_ec2nodeclass_tags = {
    ManagedBy = "karpenter"
  }
  
  karpenter_block_device_mappings = []

  nginx_name            = "nginx-demo"
  nginx_namespace       = "default"
  nginx_deployment_name = "nginx"
  nginx_image           = "nginx:1.27-alpine"
  nginx_replicas        = 2
  nginx_timeout         = 300
  
  nginx_resources = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "300m"
      memory = "256Mi"
    }
  }
  
  nginx_hpa_min_replicas       = 2
  nginx_hpa_max_replicas       = 20
  nginx_hpa_target_cpu_percent = 60
  
  nginx_ingress_class  = "alb"
  nginx_alb_scheme     = "internet-facing"
  nginx_alb_target_type = "ip"

  cleanup_delay_nginx                = 45
  cleanup_delay_karpenter_resources  = 30
  cleanup_delay_karpenter_controller = 10
  cleanup_delay_controllers          = 30
  cleanup_delay_metrics              = 60
  cleanup_delay_final                = 30
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
  
  cluster_version                          = local.cluster_version
  authentication_mode                      = local.authentication_mode
  cluster_endpoint_public_access           = local.cluster_endpoint_public_access
  cluster_endpoint_private_access          = local.cluster_endpoint_private_access
  enable_cluster_creator_admin_permissions = local.enable_cluster_creator_admin_permissions
  admin_role_arns                          = local.admin_role_arns
  
  anchor_node_group_name  = local.anchor_node_group_name
  anchor_instance_types   = local.anchor_instance_types
  anchor_min_size         = local.anchor_min_size
  anchor_desired_size     = local.anchor_desired_size
  anchor_max_size         = local.anchor_max_size
  anchor_node_labels      = local.anchor_node_labels
  anchor_node_taints      = local.anchor_node_taints
  
  enable_alb_controller = local.enable_alb_controller
  enable_metrics_server = local.enable_metrics_server
  enable_karpenter      = local.enable_karpenter
  enable_nginx          = local.enable_nginx

  alb_controller_name                 = local.alb_controller_name
  alb_controller_namespace            = local.alb_controller_namespace
  alb_controller_service_account_name = local.alb_controller_service_account_name
  alb_controller_chart_version        = local.alb_controller_chart_version
  alb_controller_timeout              = local.alb_controller_timeout
  alb_controller_extra_values         = local.alb_controller_extra_values

  metrics_server_name          = local.metrics_server_name
  metrics_server_namespace     = local.metrics_server_namespace
  metrics_server_chart_version = local.metrics_server_chart_version
  metrics_server_insecure_tls  = local.metrics_server_insecure_tls
  metrics_server_timeout       = local.metrics_server_timeout
  metrics_server_extra_values  = local.metrics_server_extra_values

  karpenter_namespace              = local.karpenter_namespace
  karpenter_service_account_name   = local.karpenter_service_account_name
  karpenter_chart_version          = local.karpenter_chart_version
  karpenter_crd_version            = local.karpenter_crd_version
  karpenter_replicas               = local.karpenter_replicas
  karpenter_priority_class         = local.karpenter_priority_class
  karpenter_dns_policy             = local.karpenter_dns_policy
  karpenter_timeout_crd            = local.karpenter_timeout_crd
  karpenter_timeout_controller     = local.karpenter_timeout_controller
  karpenter_timeout_resources      = local.karpenter_timeout_resources
  karpenter_resources              = local.karpenter_resources
  karpenter_feature_gates          = local.karpenter_feature_gates
  karpenter_ami_family             = local.karpenter_ami_family
  karpenter_ami_alias              = local.karpenter_ami_alias
  karpenter_node_additional_policies = local.karpenter_node_additional_policies
  karpenter_helm_extra_values      = local.karpenter_helm_extra_values

  karpenter_nodepool_name          = local.karpenter_nodepool_name
  karpenter_instance_families      = local.karpenter_instance_families
  karpenter_capacity_types         = local.karpenter_capacity_types
  karpenter_nodepool_labels        = local.karpenter_nodepool_labels
  karpenter_consolidation_policy   = local.karpenter_consolidation_policy
  karpenter_consolidate_after      = local.karpenter_consolidate_after
  karpenter_expire_after           = local.karpenter_expire_after
  karpenter_nodepool_cpu_limit     = local.karpenter_nodepool_cpu_limit
  karpenter_nodepool_memory_limit  = local.karpenter_nodepool_memory_limit
  karpenter_nodepool_weight        = local.karpenter_nodepool_weight

  karpenter_ec2nodeclass_name      = local.karpenter_ec2nodeclass_name
  karpenter_ec2nodeclass_tags      = local.karpenter_ec2nodeclass_tags
  karpenter_block_device_mappings  = local.karpenter_block_device_mappings
  
  nginx_name                   = local.nginx_name
  nginx_namespace              = local.nginx_namespace
  nginx_deployment_name        = local.nginx_deployment_name
  nginx_image                  = local.nginx_image
  nginx_replicas               = local.nginx_replicas
  nginx_timeout                = local.nginx_timeout
  nginx_resources              = local.nginx_resources
  nginx_hpa_min_replicas       = local.nginx_hpa_min_replicas
  nginx_hpa_max_replicas       = local.nginx_hpa_max_replicas
  nginx_hpa_target_cpu_percent = local.nginx_hpa_target_cpu_percent
  nginx_ingress_class          = local.nginx_ingress_class
  nginx_alb_scheme             = local.nginx_alb_scheme
  nginx_alb_target_type        = local.nginx_alb_target_type

  cleanup_delay_nginx                = local.cleanup_delay_nginx
  cleanup_delay_karpenter_resources  = local.cleanup_delay_karpenter_resources
  cleanup_delay_karpenter_controller = local.cleanup_delay_karpenter_controller
  cleanup_delay_controllers          = local.cleanup_delay_controllers
  cleanup_delay_metrics              = local.cleanup_delay_metrics
  cleanup_delay_final                = local.cleanup_delay_final
}