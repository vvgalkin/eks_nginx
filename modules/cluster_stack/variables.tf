#############################
# Core
#############################
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
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# ✅ ИСПРАВЛЕНО: переименовано и добавлено описание
variable "admin_principals" {
  description = "List of IAM user/role ARNs to grant cluster admin access"
  type        = list(string)
  default     = []
}

#############################
# Networking
#############################
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

# ✅ ДОБАВЛЕНО: управление NAT gateway
variable "single_nat_gateway" {
  description = "Use single NAT gateway (true for demo, false for prod)"
  type        = bool
  default     = true
}

#############################
# EKS Anchor Node Group
#############################
variable "anchor_instance_types" {
  description = "Instance types for anchor node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "anchor_min_size" {
  description = "Minimum nodes"
  type        = number
  default     = 1
}

variable "anchor_desired_size" {
  description = "Desired nodes"
  type        = number
  default     = 1
}

variable "anchor_max_size" {
  description = "Maximum nodes"
  type        = number
  default     = 2
}

#############################
# Addons
#############################
variable "enable_alb_controller" {
  description = "Install AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Install metrics-server"
  type        = bool
  default     = true
}

variable "enable_karpenter" {
  description = "Install Karpenter"
  type        = bool
  default     = true
}

variable "enable_nginx" {
  description = "Deploy nginx demo"
  type        = bool
  default     = true
}

#############################
# Chart Versions
#############################
variable "alb_controller_chart_version" {
  description = "ALB controller chart version"
  type        = string
  default     = "1.8.1"
}

variable "alb_controller_extra_values" {
  description = "Extra Helm values for ALB controller"
  type        = list(any)
  default     = []
}

variable "metrics_server_chart_version" {
  description = "Metrics server chart version"
  type        = string
  default     = "3.12.1"
}

variable "metrics_server_extra_values" {
  description = "Extra Helm values for metrics-server"
  type        = list(any)
  default     = []
}

variable "karpenter_crd_version" {
  description = "Karpenter CRD version"
  type        = string
  default     = "0.36.0"
}

variable "karpenter_chart_version" {
  description = "Karpenter chart version"
  type        = string
  default     = "0.36.0"
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

variable "karpenter_helm_extra_values" {
  description = "Extra Helm values for Karpenter"
  type        = list(any)
  default     = []
}
