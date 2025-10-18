variable "region" {
  description = "AWS region"
  type        = string
}

variable "name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "admin_role_arns" {
  description = "List of IAM role ARNs for cluster admin access"
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for all AZs (cost optimization)"
  type        = bool
  default     = true
}

variable "authentication_mode" {
  description = "Authentication mode for the cluster. Valid values: API, API_AND_CONFIG_MAP, CONFIG_MAP"
  type        = string
  default     = "API_AND_CONFIG_MAP"
  
  validation {
    condition     = contains(["API", "API_AND_CONFIG_MAP", "CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode must be one of: API, API_AND_CONFIG_MAP, CONFIG_MAP"
  }
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Enable cluster creator admin permissions"
  type        = bool
  default     = true
}

variable "anchor_node_group_name" {
  description = "Name for the core/anchor managed node group"
  type        = string
  default     = "core"
}

variable "anchor_instance_types" {
  description = "Instance types for core node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "anchor_min_size" {
  description = "Minimum size of core node group"
  type        = number
  default     = 1
}

variable "anchor_desired_size" {
  description = "Desired size of core node group"
  type        = number
  default     = 1
}

variable "anchor_max_size" {
  description = "Maximum size of core node group"
  type        = number
  default     = 2
}

variable "anchor_node_labels" {
  description = "Labels for core node group"
  type        = map(string)
  default = {
    role = "core"
  }
}

variable "anchor_node_taints" {
  description = "Taints for core node group"
  type        = list(map(string))
  default     = []
}

variable "enable_alb_controller" {
  description = "Install AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Install Metrics Server"
  type        = bool
  default     = true
}

variable "enable_karpenter" {
  description = "Install Karpenter"
  type        = bool
  default     = true
}

variable "enable_nginx" {
  description = "Deploy nginx demo application"
  type        = bool
  default     = true
}

variable "alb_controller_chart_version" {
  description = "AWS Load Balancer Controller chart version"
  type        = string
  default     = "1.8.1"
}

variable "metrics_server_chart_version" {
  description = "Metrics Server chart version"
  type        = string
  default     = "3.12.1"
}

variable "karpenter_chart_version" {
  description = "Karpenter chart version"
  type        = string
  default     = "1.8.0"
}

variable "karpenter_crd_version" {
  description = "Karpenter CRD chart version"
  type        = string
  default     = "1.8.0"
}

variable "karpenter_provider_version" {
  description = "Karpenter Provider AWS version (defaults to karpenter_chart_version if null)"
  type        = string
  default     = null
}

variable "alb_controller_extra_values" {
  description = "Extra values for ALB controller Helm chart"
  type        = list(any)
  default     = []
}

variable "metrics_server_extra_values" {
  description = "Extra values for Metrics Server Helm chart"
  type        = list(any)
  default     = []
}

variable "karpenter_helm_extra_values" {
  description = "Extra values for Karpenter Helm chart"
  type        = list(any)
  default     = []
}

variable "metrics_server_insecure_tls" {
  description = "Enable insecure TLS for metrics-server (for testing/development)"
  type        = bool
  default     = true
}

variable "karpenter_ami_family" {
  description = "AMI family for Karpenter EC2NodeClass (AL2023, AL2, Bottlerocket, etc.)"
  type        = string
  default     = "AL2023"
}

variable "karpenter_ami_alias" {
  description = "AMI alias for Karpenter EC2NodeClass. If null, automatically determined from karpenter_ami_family"
  type        = string
  default     = null
}

variable "karpenter_node_additional_policies" {
  description = "Additional IAM policies for Karpenter nodes"
  type        = map(string)
  default = {
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }
}

variable "karpenter_namespace" {
  description = "Kubernetes namespace for Karpenter"
  type        = string
  default     = "karpenter"
}

variable "karpenter_service_account_name" {
  description = "Service account name for Karpenter"
  type        = string
  default     = "karpenter"
}

variable "karpenter_replicas" {
  description = "Number of Karpenter controller replicas"
  type        = number
  default     = 1
}

variable "karpenter_priority_class" {
  description = "Priority class for Karpenter pods"
  type        = string
  default     = "system-cluster-critical"
}

variable "karpenter_dns_policy" {
  description = "DNS policy for Karpenter pods"
  type        = string
  default     = "Default"
}

variable "karpenter_resources" {
  description = "Resource requests and limits for Karpenter controller (as map)"
  type        = map(map(string))
  default = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1"
      memory = "512Mi"
    }
  }
}

variable "karpenter_feature_gates" {
  description = "Feature gates for Karpenter (as map of bools)"
  type        = map(bool)
  default = {
    reserved_capacity          = true
    spot_to_spot_consolidation = false
    node_repair                = false
    node_overlay               = false
    static_capacity            = false
  }
}

variable "karpenter_timeout_crd" {
  description = "Timeout for Karpenter CRD Helm release (seconds)"
  type        = number
  default     = 1200
}

variable "karpenter_timeout_controller" {
  description = "Timeout for Karpenter controller Helm release (seconds)"
  type        = number
  default     = 1200
}

variable "karpenter_timeout_resources" {
  description = "Timeout for Karpenter resources Helm release (seconds)"
  type        = number
  default     = 1200
}


variable "karpenter_nodepool_name" {
  description = "Name for the default Karpenter NodePool"
  type        = string
  default     = "default"
}

variable "karpenter_nodepool_labels" {
  description = "Labels for Karpenter managed nodes"
  type        = map(string)
  default = {
    role = "workload"
  }
}

variable "karpenter_instance_families" {
  description = "List of EC2 instance families for Karpenter nodes"
  type        = list(string)
  default     = ["t3", "t3a", "m6i", "c6i"]
}

variable "karpenter_capacity_types" {
  description = "List of capacity types (spot, on-demand)"
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "karpenter_consolidation_policy" {
  description = "Consolidation policy for Karpenter"
  type        = string
  default     = "WhenEmptyOrUnderutilized"
}

variable "karpenter_consolidate_after" {
  description = "Time to wait before consolidating nodes"
  type        = string
  default     = "1m"
}

variable "karpenter_expire_after" {
  description = "Time after which nodes expire and are replaced. Set to null to disable."
  type        = string
  default     = null
}

variable "karpenter_nodepool_cpu_limit" {
  description = "Total CPU limit for the NodePool"
  type        = string
  default     = "200"
}

variable "karpenter_nodepool_memory_limit" {
  description = "Total memory limit for the NodePool. Set to null for no limit."
  type        = string
  default     = null
}

variable "karpenter_nodepool_weight" {
  description = "Weight for the NodePool (0-100)"
  type        = number
  default     = 10
}

variable "karpenter_ec2nodeclass_name" {
  description = "Name for the Karpenter EC2NodeClass"
  type        = string
  default     = "default-ec2"
}

variable "karpenter_ec2nodeclass_tags" {
  description = "Additional tags for EC2 instances managed by Karpenter"
  type        = map(string)
  default     = {}
}

variable "karpenter_block_device_mappings" {
  description = "Block device mappings for Karpenter nodes (list of maps)"
  type        = list(map(any))
  default     = []
}


variable "alb_controller_name" {
  description = "Helm release name for AWS Load Balancer Controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "alb_controller_namespace" {
  description = "Kubernetes namespace for AWS Load Balancer Controller"
  type        = string
  default     = "kube-system"
}

variable "alb_controller_service_account_name" {
  description = "Service account name for AWS Load Balancer Controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "alb_controller_timeout" {
  description = "Timeout for ALB controller Helm release (seconds)"
  type        = number
  default     = 600
}

variable "metrics_server_name" {
  description = "Helm release name for Metrics Server"
  type        = string
  default     = "metrics-server"
}

variable "metrics_server_namespace" {
  description = "Kubernetes namespace for Metrics Server"
  type        = string
  default     = "kube-system"
}

variable "metrics_server_timeout" {
  description = "Timeout for Metrics Server Helm release (seconds)"
  type        = number
  default     = 300
}


variable "nginx_name" {
  description = "Name for the nginx demo application"
  type        = string
  default     = "nginx-demo"
}

variable "nginx_namespace" {
  description = "Kubernetes namespace for nginx demo"
  type        = string
  default     = "default"
}

variable "nginx_deployment_name" {
  description = "Deployment name for nginx"
  type        = string
  default     = "nginx"
}

variable "nginx_image" {
  description = "Docker image for nginx"
  type        = string
  default     = "nginx:1.27-alpine"
}

variable "nginx_replicas" {
  description = "Initial number of nginx replicas"
  type        = number
  default     = 2
}

variable "nginx_resources" {
  description = "Resource requests and limits for nginx pods (as map)"
  type        = map(map(string))
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "300m"
      memory = "256Mi"
    }
  }
}

variable "nginx_hpa_min_replicas" {
  description = "Minimum replicas for nginx HPA"
  type        = number
  default     = 2
}

variable "nginx_hpa_max_replicas" {
  description = "Maximum replicas for nginx HPA"
  type        = number
  default     = 20
}

variable "nginx_hpa_target_cpu_percent" {
  description = "Target CPU utilization percentage for HPA"
  type        = number
  default     = 60
}

variable "nginx_ingress_class" {
  description = "Ingress class for nginx ingress"
  type        = string
  default     = "alb"
}

variable "nginx_alb_scheme" {
  description = "ALB scheme (internet-facing or internal)"
  type        = string
  default     = "internet-facing"
}

variable "nginx_alb_target_type" {
  description = "ALB target type (ip or instance)"
  type        = string
  default     = "ip"
}

variable "nginx_timeout" {
  description = "Timeout for nginx Helm release (seconds)"
  type        = number
  default     = 300
}

variable "cleanup_delay_nginx" {
  description = "Delay in seconds for nginx cleanup during destroy"
  type        = number
  default     = 45
}

variable "cleanup_delay_karpenter_resources" {
  description = "Delay in seconds for Karpenter resources cleanup"
  type        = number
  default     = 30
}

variable "cleanup_delay_karpenter_controller" {
  description = "Delay in seconds for Karpenter controller cleanup"
  type        = number
  default     = 10
}

variable "cleanup_delay_controllers" {
  description = "Delay in seconds for controllers cleanup"
  type        = number
  default     = 30
}

variable "cleanup_delay_metrics" {
  description = "Delay in seconds for metrics server cleanup"
  type        = number
  default     = 60
}

variable "cleanup_delay_final" {
  description = "Delay in seconds for final cleanup"
  type        = number
  default     = 30
}