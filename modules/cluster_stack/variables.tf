#############################
# Core / identity
#############################
variable "region" {
  description = "AWS region (e.g., eu-central-1)"
  type        = string
}

variable "name" {
  description = "EKS cluster name; used as a prefix for related resources"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.29"
}

variable "tags" {
  description = "Common tags applied to all created resources"
  type        = map(string)
  default     = {}
}

variable "admin_role_arns" {
  type    = list(string)
  default = []
}

#############################
# Networking (always create VPC)
#############################
variable "vpc_cidr" {
  description = "CIDR block for the VPC to create"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
  ]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default = [
    "10.0.101.0/24",
    "10.0.102.0/24",
    "10.0.103.0/24",
  ]
}

variable "azs" {
  description = "Availability Zones to use (e.g., [\"eu-central-1a\",\"eu-central-1b\",\"eu-central-1c\"])"
  type        = list(string)
  default = [
    "eu-central-1a",
    "eu-central-1b",
    "eu-central-1c",
  ]
}

#############################
# EKS anchor node group (minimal)
#############################
variable "anchor_instance_types" {
  description = "Instance types for the anchor (system) Managed Node Group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "anchor_min_size" {
  description = "Minimum size of the anchor node group"
  type        = number
  default     = 1
}

variable "anchor_desired_size" {
  description = "Desired size of the anchor node group"
  type        = number
  default     = 1
}

variable "anchor_max_size" {
  description = "Maximum size of the anchor node group"
  type        = number
  default     = 2
}

#############################
# Optional addons toggles
#############################
variable "enable_alb_controller" {
  description = "Install AWS Load Balancer Controller via Helm"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Install metrics-server (required for HPA)"
  type        = bool
  default     = true
}

variable "enable_nginx" {
  description = "Deploy nginx demo application"
  type        = bool
  default     = true
}

#############################
# Helm charts versions & values overrides
#############################
variable "alb_controller_chart_version" {
  description = "aws-load-balancer-controller chart version"
  type        = string
  default     = "1.8.1"
}

variable "alb_controller_extra_values" {
  description = "Extra Helm values for ALB controller (list of YAML-encodable maps)"
  type        = list(any)
  default     = []
}

variable "metrics_server_chart_version" {
  description = "metrics-server chart version"
  type        = string
  default     = "3.12.1"
}

variable "metrics_server_extra_values" {
  description = "Extra Helm values for metrics-server (list of YAML-encodable maps)"
  type        = list(any)
  default     = []
}

variable "enable_karpenter" {
  description = "Enable Karpenter deployment"
  type        = bool
  default     = true
}

variable "karpenter_crd_version" {
  description = "Karpenter CRD chart version (must match controller minor)"
  type        = string
  default     = "0.36.0"
}

variable "karpenter_chart_version" {
  description = "Karpenter controller chart version"
  type        = string
  default     = "0.36.0"
}

variable "karpenter_node_additional_policies" {
  description = "Additional IAM policies for Karpenter-managed nodes"
  type        = map(string)
  default = {
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }
}

variable "karpenter_helm_extra_values" {
  description = "Additional YAML values merged into the Karpenter Helm release"
  type        = list(any)
  default     = []
}
