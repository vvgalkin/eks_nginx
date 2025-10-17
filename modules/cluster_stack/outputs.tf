output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = local.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = local.public_subnets
}

output "karpenter_node_role_name" {
  description = "Karpenter node IAM role name"
  value       = try(module.karpenter[0].node_iam_role_name, null)
}

output "karpenter_node_role_arn" {
  description = "Karpenter node IAM role ARN"
  value       = try(module.karpenter[0].node_iam_role_arn, null)
}

output "karpenter_irsa_arn" {
  description = "Karpenter controller IAM role ARN"
  value       = try(module.karpenter[0].iam_role_arn, null)
}

output "karpenter_queue_name" {
  description = "Karpenter SQS queue name"
  value       = try(module.karpenter[0].queue_name, null)
}

output "alb_controller_role_arn" {
  description = "AWS Load Balancer Controller IAM role ARN"
  value       = try(module.alb_irsa[0].iam_role_arn, null)
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "nginx_ingress_check" {
  description = "Command to check nginx ingress and get ALB hostname"
  value       = var.enable_nginx ? "kubectl get ingress nginx -n default" : null
}