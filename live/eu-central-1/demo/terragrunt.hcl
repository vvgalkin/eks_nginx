include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/cluster_stack"

  after_hook "render_and_apply_k8s" {
    commands     = ["apply"]
    execute      = ["bash", "-c", <<-EOT
      set -euo pipefail

      if ! command -v envsubst >/dev/null; then
        echo "ERROR: install 'envsubst' (gettext package)" >&2
        exit 1
      fi

      # Outputs
      CLUSTER_NAME="$$(terraform output -raw cluster_name)"
      ROLE_NAME="$$(terraform output -raw karpenter_node_role_name || true)"
      REGION="${local.region}"
      export CLUSTER_NAME ROLE_NAME REGION

      # Пути относительно terragrunt.hcl
      WORK_DIR="$$(pwd)"
      TEMPLATES_DIR="$${WORK_DIR}/k8s/templates"
      DIST_DIR="$${WORK_DIR}/k8s/dist"

      echo "Working directory: $${WORK_DIR}"
      
      mkdir -p "$${DIST_DIR}"

      # Рендеринг
      envsubst < "$${TEMPLATES_DIR}/karpenter-ec2nodeclass.yaml.tmpl" > "$${DIST_DIR}/karpenter-ec2nodeclass.yaml"
      envsubst < "$${TEMPLATES_DIR}/karpenter-nodepool.yaml.tmpl" > "$${DIST_DIR}/karpenter-nodepool.yaml"
      cp "$${WORK_DIR}/k8s/nginx.yaml" "$${DIST_DIR}/"
      cp "$${WORK_DIR}/k8s/nginx-ingress.yaml" "$${DIST_DIR}/"

      # Apply
      aws eks update-kubeconfig --name "$${CLUSTER_NAME}" --region "$${REGION}" --kubeconfig "$${WORK_DIR}/kubeconfig"
      export KUBECONFIG="$${WORK_DIR}/kubeconfig"
      kubectl apply -f "$${DIST_DIR}/"
      
      echo "✓ Manifests applied"
    EOT
    ]
    run_on_error = false
  }
}


locals {
  # Регион для использования в after_hook
  region = "eu-central-1"
  
  # Можно менять на лету, модуль идемпотентный
  cluster_version = "1.29"

  vpc_cidr = "10.0.0.0/16"
  azs      = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]

  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  # Anchor MNG (системные поды; рабочую ёмкость даст Karpenter)
  anchor_instance_types = ["t3.medium"]
  anchor_min_size       = 1
  anchor_desired_size   = 1
  anchor_max_size       = 2

  # Addons toggles
  enable_alb_controller = true
  enable_metrics_server = true
  enable_karpenter      = true

  # Helm chart versions (при необходимости меняем здесь)
  alb_controller_chart_version = "1.8.1"
  metrics_server_chart_version = "3.12.1"
  karpenter_chart_version      = "0.36.0"

  # Доп. values при желании
  alb_controller_extra_values = []
  metrics_server_extra_values = []
  karpenter_helm_extra_values = []
}

# Подставляем значения в модуль (никакого хардкода в модуле)
inputs = {
  cluster_version = local.cluster_version

  vpc_cidr             = local.vpc_cidr
  azs                  = local.azs
  private_subnet_cidrs = local.private_subnet_cidrs
  public_subnet_cidrs  = local.public_subnet_cidrs

  anchor_instance_types = local.anchor_instance_types
  anchor_min_size       = local.anchor_min_size
  anchor_desired_size   = local.anchor_desired_size
  anchor_max_size       = local.anchor_max_size

  enable_alb_controller = local.enable_alb_controller
  enable_metrics_server = local.enable_metrics_server
  enable_karpenter      = local.enable_karpenter

  alb_controller_chart_version = local.alb_controller_chart_version
  metrics_server_chart_version = local.metrics_server_chart_version
  karpenter_chart_version      = local.karpenter_chart_version

  alb_controller_extra_values = local.alb_controller_extra_values
  metrics_server_extra_values = local.metrics_server_extra_values
  karpenter_helm_extra_values = local.karpenter_helm_extra_values
}