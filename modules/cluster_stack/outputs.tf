output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN associated with the EKS cluster"
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  description = "VPC ID used by the cluster"
  value       = local.vpc_id_out
}

output "private_subnets" {
  description = "Private subnet IDs used by the cluster"
  value       = local.private_subnets_out
}

output "public_subnets" {
  description = "Public subnet IDs used by the cluster"
  value       = local.public_subnets_out
}

output "karpenter_node_role_name" {
  description = "IAM Role name for Karpenter nodes (null when enable_karpenter = false)"
  value       = try(module.karpenter[0].node_iam_role_name, null)
}
