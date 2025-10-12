variable "region" {
  type    = string
  default = null
}

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

variable "access_entries" {
  type    = any
  default = {}
}

variable "admin_role_arns" {
  type    = list(string)
  default = []
}

variable "kms_key_owners" {
  type    = list(string)
  default = []
}

variable "kms_key_administrators" {
  type    = list(string)
  default = []
}

variable "external_dns_hosted_zone_arns" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
