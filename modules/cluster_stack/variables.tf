###########################################
# General
###########################################
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

###########################################
# VPC
###########################################
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

###########################################
# EKS Managed Node Group
###########################################
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

###########################################
# Add-ons
###########################################
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

###########################################
# Chart Versions
###########################################
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

###########################################
# Helm Chart Extra Values
###########################################
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

###########################################
# Karpenter IAM
###########################################
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