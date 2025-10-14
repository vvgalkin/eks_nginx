# EKS Demo Infrastructure

Production-ready EKS cluster with Karpenter autoscaling and demo nginx application.

## Architecture

- **VPC**: Custom VPC with private/public subnets across 3 AZs
- **EKS**: Kubernetes 1.29 with managed node group for system pods
- **Karpenter**: Autoscaling for workload pods (spot + on-demand)
- **ALB Controller**: AWS Load Balancer integration
- **Metrics Server**: Required for HPA
- **Demo App**: Nginx with HPA (2-20 replicas)

## Structure