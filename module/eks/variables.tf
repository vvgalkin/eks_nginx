variable "name" {
  type    = string
  default = null
}

variable "cluster_version" {
  type    = string
  default = null
}

variable "vpc_id" {
  type    = string
  default = null
}

variable "private_subnets" {
  type    = list(string)
  default = null
}

variable "public_subnets" {
  type    = list(string)
  default = null
}

variable "key_pair_name" {
  type    = string
  default = null
}

variable "default_instance_types" {
  type    = list(string)
  default = ["c5d.large"]
}

variable "default_ami_type" {
  type    = string
  default = null
}

variable "default_ami_id" {
  type    = string
  default = null
}

variable "node_groups" {
  type    = any
  default = {}
}

variable "aws_auth_roles" {
  type    = any
  default = []
}

variable "access_entries" {
  type    = any
  default = {}
}

variable "admin_role_arns" {
  type    = list(string)
  default = []
}

############
##### KMS
############

variable "kms_key_owners" {
  type    = list(string)
  default = []
}

variable "kms_key_administrators" {
  type    = list(string)
  default = []
}

############
##### ARGOCD
############

variable "reg-cluster-in-argocd" {
  type    = bool
  default = false
}

variable "project" {
  type    = string
  default = null
}

variable "argocd_url" {
  type    = string
  default = null
}

variable "argocd_user" {
  type    = string
  default = null
}

variable "argocd_password" {
  type    = string
  default = null
}

variable "argocd_deployer_role_arn" {
  type    = string
  default = "arn:aws:iam::646053551022:role/argocd-irsa"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "argocd_project_mapping_oidc_admin" {
  type    = list(string)
  default = []
}

variable "argocd_project_mapping_oidc_dev" {
  type    = list(string)
  default = []
}

variable "argocd_extra_roles" {
  type    = list(any)
  default = []
}

#############
##### ROUTE53
#############

variable "external_dns_hosted_zone_arns" {
  type    = list(string)
  default = []
}

##################
##### ASG Policies
##################

variable "default_asg_values" {
  type        = any
  default     = {}
  description = <<EOF
    Default values:
    ```
      ram = {
        cloudwatch_metric_name = "MEM_USED_PERCENT"
        cloudwatch_namespace   = "EKS/$var.name"
        target_value           = 70
      }
      cpu = {
        target_value           = 70
      }
    ```
  EOF
}
