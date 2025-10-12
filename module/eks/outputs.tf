output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "kms_key_arn" {
  value = module.eks.kms_key_arn
}

output "kms_key_id" {
  value = module.eks.kms_key_id
}

output "aws_loadbalancer_irsa" {
  value = module.aws_loadbalancer_irsa.iam_role_arn
}

output "external_dns_irsa" {
  value = module.external_dns_irsa.iam_role_arn
}

output "cluster_primary_security_group_id" {
  value = module.eks.cluster_primary_security_group_id
}

# output "eks_managed_node_groups" {
#   description = "Map of attribute maps for all EKS managed node groups created"
#   value       = module.eks.eks_managed_node_groups
# }