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

variable "admin_principals" {
  type    = list(string)
  default = []
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "azs" {
  type    = list(string)
  default = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "anchor_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "anchor_min_size" {
  type    = number
  default = 1
}

variable "anchor_desired_size" {
  type    = number
  default = 1
}

variable "anchor_max_size" {
  type    = number
  default = 2
}

variable "enable_alb_controller" {
  type    = bool
  default = true
}

variable "enable_metrics_server" {
  type    = bool
  default = true
}

variable "enable_karpenter" {
  type    = bool
  default = true
}

variable "enable_nginx" {
  type    = bool
  default = true
}

variable "alb_controller_chart_version" {
  type    = string
  default = "1.8.1"
}

variable "alb_controller_extra_values" {
  type    = list(any)
  default = []
}

variable "metrics_server_chart_version" {
  type    = string
  default = "3.12.1"
}

variable "metrics_server_extra_values" {
  type    = list(any)
  default = []
}

variable "karpenter_crd_version" {
  type    = string
  default = "0.36.0"
}

variable "karpenter_chart_version" {
  type    = string
  default = "0.36.0"
}

variable "karpenter_node_additional_policies" {
  type = map(string)
  default = {
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }
}

variable "karpenter_helm_extra_values" {
  type    = list(any)
  default = []
}
