locals {
  region = "eu-central-1"
  name   = "demo-eks-eu-central-1"

  tags = {
    Project     = "eks-demo"
    Environment = "demo"
    ManagedBy   = "terragrunt"
  }
}

# локальный state — для тестового задания этого более чем достаточно
remote_state {
  backend = "local"

  config = {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  }
}

# общие inputs для всех окружений
inputs = {
  region = local.region
  name   = local.name
  tags   = local.tags
}
