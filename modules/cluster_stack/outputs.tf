output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "vpc_id" {
  value = local.vpc_id_out
}

output "private_subnets" {
  value = local.private_subnets_out
}

output "public_subnets" {
  value = local.public_subnets_out
}

output "karpenter_node_role_name" {
  value = try(module.karpenter[0].node_iam_role_name, null)
}
