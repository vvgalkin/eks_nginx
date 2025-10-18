# EKS Cluster Stack Module

Полнофункциональный Terraform модуль для развертывания Amazon EKS кластера с поддержкой автоскейлинга Karpenter, AWS Load Balancer Controller, Metrics Server и демо-приложением Nginx.

## Описание

Модуль `cluster_stack` создает production-ready EKS кластер со следующими компонентами:

- **VPC** с приватными и публичными подсетями в нескольких зонах доступности
- **EKS кластер** (Kubernetes 1.29) с управляемой node group для core workloads
- **Karpenter** 1.8.1 для динамического автоскейлинга worker nodes
- **AWS Load Balancer Controller** для управления ALB/NLB через Kubernetes Ingress
- **Metrics Server** для мониторинга ресурсов pods и nodes
- **Nginx demo приложение** с HPA и ALB Ingress (опционально)

## Архитектура

```
┌─────────────────────────────────────────────────────────────────┐
│                           AWS Region                             │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                         VPC                                │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │  │
│  │  │   AZ-A      │  │   AZ-B      │  │   AZ-C      │       │  │
│  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │       │  │
│  │  │ │ Private │ │  │ │ Private │ │  │ │ Private │ │       │  │
│  │  │ │ Subnet  │ │  │ │ Subnet  │ │  │ │ Subnet  │ │       │  │
│  │  │ └────┬────┘ │  │ └────┬────┘ │  │ └────┬────┘ │       │  │
│  │  │      │      │  │      │      │  │      │      │       │  │
│  │  │ ┌────▼────┐ │  │ ┌────▼────┐ │  │ ┌────▼────┐ │       │  │
│  │  │ │ Public  │ │  │ │ Public  │ │  │ │ Public  │ │       │  │
│  │  │ │ Subnet  │ │  │ │ Subnet  │ │  │ │ Subnet  │ │       │  │
│  │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │       │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘       │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────┐    │  │
│  │  │              EKS Control Plane                    │    │  │
│  │  │  - API Server                                     │    │  │
│  │  │  - etcd                                           │    │  │
│  │  │  - Controller Manager                             │    │  │
│  │  └──────────────────────────────────────────────────┘    │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────┐    │  │
│  │  │           Worker Nodes                            │    │  │
│  │  │  ┌────────────────────────────────────────────┐  │    │  │
│  │  │  │  Core Node Group (EKS Managed)             │  │    │  │
│  │  │  │  - Karpenter Controller                    │  │    │  │
│  │  │  │  - AWS LB Controller                       │  │    │  │
│  │  │  │  - Metrics Server                          │  │    │  │
│  │  │  │  - CoreDNS, kube-proxy, vpc-cni           │  │    │  │
│  │  │  └────────────────────────────────────────────┘  │    │  │
│  │  │  ┌────────────────────────────────────────────┐  │    │  │
│  │  │  │  Karpenter Auto-Scaled Nodes               │  │    │  │
│  │  │  │  - Application Workloads                   │  │    │  │
│  │  │  │  - Spot & On-Demand Instances              │  │    │  │
│  │  │  │  - Auto-consolidation                      │  │    │  │
│  │  │  └────────────────────────────────────────────┘  │    │  │
│  │  └──────────────────────────────────────────────────┘    │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Структура модуля

```
modules/cluster_stack/
├── main.tf              # Основная конфигурация
├── variables.tf         # Входные переменные
├── outputs.tf           # Выходные значения
├── versions.tf          # Версии providers
└── charts/              # Helm чарты
    ├── karpenter-resources/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── ec2nodeclass.yaml
    │       └── nodepool.yaml
    └── nginx/
        ├── Chart.yaml
        └── templates/
            ├── deployment.yaml
            ├── service.yaml
            ├── hpa.yaml
            └── ingress.yaml
```

## Использование

### Базовая конфигурация через Terragrunt

```hcl
# terragrunt.hcl
locals {
  region         = "eu-central-1"
  name           = "demo-eks-eu-central-1"
  cluster_version = "1.29"
  
  tags = {
    Project     = "eks-demo"
    Environment = "demo"
    ManagedBy   = "terragrunt"
  }
}

terraform {
  source = "./modules/cluster_stack"
}

inputs = {
  region          = local.region
  name            = local.name
  cluster_version = local.cluster_version
  tags            = local.tags
  
  # VPC Configuration
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  single_nat_gateway   = true
  
  # Core Node Group
  anchor_instance_types = ["t3.medium"]
  anchor_min_size       = 1
  anchor_desired_size   = 1
  anchor_max_size       = 2
  
  # Add-ons
  enable_alb_controller = true
  enable_metrics_server = true
  enable_karpenter      = true
  enable_nginx          = true
  
  # Karpenter Configuration
  karpenter_ami_family = "AL2023"
}
```

### Прямое использование Terraform

```hcl
module "eks_cluster" {
  source = "./modules/cluster_stack"
  
  region          = "eu-central-1"
  name            = "my-eks-cluster"
  cluster_version = "1.29"
  
  vpc_cidr = "10.0.0.0/16"
  azs      = ["eu-central-1a", "eu-central-1b"]
  
  enable_karpenter = true
  
  tags = {
    Environment = "production"
  }
}
```

## Переменные

### Основные переменные

| Имя | Тип | Описание | По умолчанию | Обязательна |
|-----|-----|----------|--------------|-------------|
| `region` | `string` | AWS регион | - | Да |
| `name` | `string` | Имя EKS кластера | - | Да |
| `cluster_version` | `string` | Версия Kubernetes | `"1.29"` | Нет |
| `tags` | `map(string)` | Общие теги для всех ресурсов | `{}` | Нет |

### Сетевые переменные

| Имя | Тип | Описание | По умолчанию |
|-----|-----|----------|--------------|
| `vpc_cidr` | `string` | CIDR блок VPC | `"10.0.0.0/16"` |
| `azs` | `list(string)` | Availability Zones | `["eu-central-1a", "eu-central-1b", "eu-central-1c"]` |
| `private_subnet_cidrs` | `list(string)` | CIDR приватных подсетей | `["10.0.1.0/24", ...]` |
| `public_subnet_cidrs` | `list(string)` | CIDR публичных подсетей | `["10.0.101.0/24", ...]` |
| `single_nat_gateway` | `bool` | Использовать один NAT Gateway | `true` |

### Node Group переменные

| Имя | Тип | Описание | По умолчанию |
|-----|-----|----------|--------------|
| `anchor_instance_types` | `list(string)` | Типы инстансов для core node group | `["t3.medium"]` |
| `anchor_min_size` | `number` | Минимальное количество нод | `1` |
| `anchor_desired_size` | `number` | Желаемое количество нод | `1` |
| `anchor_max_size` | `number` | Максимальное количество нод | `2` |

### Add-ons переменные

| Имя | Тип | Описание | По умолчанию |
|-----|-----|----------|--------------|
| `enable_alb_controller` | `bool` | Установить AWS Load Balancer Controller | `true` |
| `enable_metrics_server` | `bool` | Установить Metrics Server | `true` |
| `enable_karpenter` | `bool` | Установить Karpenter | `true` |
| `enable_nginx` | `bool` | Развернуть nginx demo приложение | `true` |

### Karpenter переменные

| Имя | Тип | Описание | По умолчанию |
|-----|-----|----------|--------------|
| `karpenter_chart_version` | `string` | Версия Karpenter Helm chart | `"1.8.0"` |
| `karpenter_crd_version` | `string` | Версия Karpenter CRD chart | `"1.8.0"` |
| `karpenter_ami_family` | `string` | AMI семейство для нод (AL2023, AL2, Bottlerocket) | `"AL2023"` |
| `karpenter_node_additional_policies` | `map(string)` | Дополнительные IAM политики для нод | См. ниже |

**Дефолтные IAM политики для Karpenter nodes:**
```hcl
{
  AmazonSSMManagedInstanceCore         = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  AmazonEC2ContainerRegistryReadOnly   = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  AmazonEKSWorkerNodePolicy            = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  AmazonEKS_CNI_Policy                 = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
```

### Версии чартов

| Имя | По умолчанию | Описание |
|-----|--------------|----------|
| `alb_controller_chart_version` | `"1.8.1"` | AWS Load Balancer Controller |
| `metrics_server_chart_version` | `"3.12.1"` | Metrics Server |

## Outputs

| Имя | Описание |
|-----|----------|
| `cluster_name` | Имя EKS кластера |
| `cluster_endpoint` | Endpoint API сервера |
| `cluster_version` | Версия Kubernetes |
| `cluster_security_group_id` | ID security group кластера |
| `oidc_provider_arn` | ARN OIDC провайдера |
| `vpc_id` | ID VPC |
| `private_subnets` | Список ID приватных подсетей |
| `public_subnets` | Список ID публичных подсетей |
| `karpenter_node_role_name` | Имя IAM роли для Karpenter нод |
| `karpenter_node_role_arn` | ARN IAM роли для Karpenter нод |
| `karpenter_irsa_arn` | ARN IAM роли Karpenter контроллера |
| `karpenter_queue_name` | Имя SQS очереди Karpenter |
| `alb_controller_role_arn` | ARN IAM роли ALB контроллера |
| `kubeconfig_command` | Команда для обновления kubeconfig |
| `nginx_ingress_check` | Команда для проверки nginx ingress |

## Компоненты

### 1. VPC

- Приватные и публичные подсети в нескольких AZ
- NAT Gateway для исходящего трафика (опционально single NAT)
- Автоматическое тегирование подсетей для EKS и Load Balancers
- Internet Gateway для публичного доступа

### 2. EKS Cluster

- Managed control plane
- API server доступен публично и приватно
- Аддоны: `coredns`, `kube-proxy`, `vpc-cni`, `eks-pod-identity-agent`
- Authentication mode: `API_AND_CONFIG_MAP`
- Поддержка IAM ролей для admin доступа через Access Entries

### 3. Core Node Group

- EKS Managed Node Group для системных компонентов
- Запускается в приватных подсетях
- Label: `role=core`
- Размещает: Karpenter, ALB Controller, Metrics Server, CoreDNS

### 4. Karpenter

**Версия**: 1.8.1

**Возможности**:
- Динамическое создание и удаление worker nodes
- Поддержка Spot и On-Demand инстансов
- Автоматическая консолидация нод
- Быстрая реакция на pending pods (секунды vs минуты у Cluster Autoscaler)

**Конфигурация**:
- **EC2NodeClass**: Определяет параметры EC2 инстансов
  - AMI Family: AL2023 (Amazon Linux 2023)
  - Автоматический выбор подсетей по тегам
  - Автоматический выбор security groups
  - IAM роль с необходимыми политиками

- **NodePool**: Определяет параметры автоскейлинга
  - Instance families: t3, t3a, m6i, c6i
  - Capacity types: Spot и On-Demand
  - Consolidation policy: WhenEmptyOrUnderutilized
  - CPU limit: 200 cores
  - Weight: 10%

**Feature Gates**:
```
ReservedCapacity=true
SpotToSpotConsolidation=false
NodeRepair=false
NodeOverlay=false
StaticCapacity=false
```

### 5. AWS Load Balancer Controller

**Версия**: 1.9.2 (совместима с Kubernetes 1.29+)

**Возможности**:
- Автоматическое создание ALB/NLB для Ingress ресурсов
- Интеграция с AWS WAF
- Target type: IP (для работы с Fargate и лучшей производительности)
- IRSA для безопасного доступа к AWS API

### 6. Metrics Server

**Версия**: 3.12.1

**Возможности**:
- Сбор метрик CPU и памяти с нод и pods
- Необходим для работы HPA (Horizontal Pod Autoscaler)
- Возможность работы с самоподписанными сертификатами (`--kubelet-insecure-tls`)

### 7. Nginx Demo Application

**Компоненты**:
- **Deployment**: 2 реплики nginx:1.27-alpine
- **Service**: ClusterIP на порту 80
- **HPA**: Автоскейлинг от 2 до 20 реплик при CPU > 60%
- **Ingress**: ALB с internet-facing схемой

**Resource Requests/Limits**:
```yaml
requests:
  cpu: 100m
  memory: 128Mi
limits:
  cpu: 300m
  memory: 256Mi
```

## Развертывание

### Шаг 1: Инициализация

```bash
# С Terragrunt
terragrunt init

# С Terraform
terraform init
```

### Шаг 2: Планирование

```bash
# С Terragrunt
terragrunt plan

# С Terraform
terraform plan
```

### Шаг 3: Применение

```bash
# С Terragrunt
terragrunt apply

# С Terraform
terraform apply
```

**Время развертывания**: ~20-25 минут

### Шаг 4: Подключение к кластеру

```bash
# Обновить kubeconfig
aws eks update-kubeconfig --region eu-central-1 --name demo-eks-eu-central-1

# Проверить ноды
kubectl get nodes

# Проверить поды
kubectl get pods -A

# Проверить Karpenter
kubectl get nodepools
kubectl get ec2nodeclasses

# Проверить nginx ingress и получить ALB URL
kubectl get ingress nginx -n default
```

## Тестирование Karpenter

### 1. Создать тестовое приложение

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 0
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      containers:
      - name: inflate
        image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        resources:
          requests:
            cpu: 1
            memory: 1Gi
EOF
```

### 2. Увеличить количество реплик

```bash
kubectl scale deployment inflate --replicas=10
```

### 3. Наблюдать за созданием нод

```bash
# Смотреть логи Karpenter
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter

# Смотреть за нодами
kubectl get nodes -w

# Проверить pending pods
kubectl get pods -o wide
```

### 4. Уменьшить нагрузку

```bash
kubectl scale deployment inflate --replicas=0

# Karpenter автоматически удалит лишние ноды через ~1 минуту
```

## Мониторинг и отладка

### Проверка статуса компонентов

```bash
# Karpenter
kubectl get pods -n karpenter
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

# AWS Load Balancer Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Metrics Server
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl top nodes
kubectl top pods
```

### Проверка Karpenter ресурсов

```bash
# NodePools
kubectl get nodepools
kubectl describe nodepool default

# EC2NodeClasses
kubectl get ec2nodeclasses
kubectl describe ec2nodeclass default-ec2

# Events
kubectl get events -n karpenter --sort-by='.lastTimestamp'
```

### Проверка ALB

```bash
# Получить ALB hostname
kubectl get ingress nginx -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Проверить доступность
curl http://$(kubectl get ingress nginx -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

## Безопасность

### IAM Roles

**Karpenter Controller Role**:
- Управление EC2 инстансами (запуск, остановка, терминация)
- Управление ENI
- Доступ к SQS для spot interruption notices
- Создание и управление IAM Instance Profiles

**Karpenter Node Role**:
- Регистрация в EKS кластере
- Доступ к ECR для pull образов
- SSM для удаленного доступа
- CNI для сетевого взаимодействия

**ALB Controller Role**:
- Создание и управление ALB/NLB
- Управление Target Groups
- Создание Security Groups
- Доступ к WAF

### Network Security

- Worker nodes в приватных подсетях
- NAT Gateway для исходящего трафика
- Security Groups автоматически управляются EKS
- ALB в публичных подсетях с контролируемым доступом

### Best Practices

1. Используйте отдельные IAM роли для каждого сервиса (IRSA)
2. Ограничьте admin доступ через `admin_role_arns`
3. Включите CloudTrail для аудита
4. Используйте Pod Security Standards
5. Регулярно обновляйте версии компонентов

## Обновление и обслуживание

### Обновление версии Kubernetes

```hcl
# В terragrunt.hcl или terraform.tfvars
cluster_version = "1.30"  # Изменить версию
```

```bash
terragrunt apply
```

**Важно**: Обновление происходит в следующем порядке:
1. Control plane
2. Core node group
3. Karpenter nodes (автоматически при замене)

### Обновление add-ons

```hcl
karpenter_chart_version       = "1.9.0"
alb_controller_chart_version  = "1.10.0"
metrics_server_chart_version  = "3.13.0"
```

### Масштабирование

**Vertical scaling (Core nodes)**:
```hcl
anchor_instance_types = ["t3.large"]  # Изменить тип инстанса
```

**Horizontal scaling (Core nodes)**:
```hcl
anchor_desired_size = 2  # Увеличить количество нод
anchor_max_size     = 3
```

## Удаление

### Правильная последовательность destroy

Модуль включает автоматическую последовательность очистки через `null_resource`:

```bash
terragrunt destroy
```

**Процесс очистки** (автоматический):
1. Nginx и ALB ресурсы (45 секунд)
2. Karpenter NodePools и drain nodes (30 секунд)
3. Karpenter Controller (10 секунд)
4. Karpenter CRDs и ALB Controller (30 секунд)
5. Metrics Server и ожидание ENI cleanup (60 секунд)
6. Финальная очистка перед destroy EKS и VPC (30 секунд)

**Общее время destroy**: ~5-7 минут

### Ручная очистка (если необходимо)

```bash
# Удалить все workloads
kubectl delete deployments --all -A
kubectl delete services --all -A --field-selector metadata.name!=kubernetes

# Удалить Karpenter nodes
kubectl delete nodepools --all

# Подождать удаления нод
kubectl get nodes -w

# Destroy инфраструктуру
terragrunt destroy
```

## Troubleshooting

### Проблема: Karpenter не создает ноды

**Решение**:
```bash
# Проверить логи
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

# Проверить NodePool
kubectl describe nodepool default

# Проверить EC2NodeClass
kubectl describe ec2nodeclass default-ec2

# Проверить IAM роли
aws iam get-role --role-name karpenter-node-<cluster-name>
```

### Проблема: ALB не создается

**Решение**:
```bash
# Проверить controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Проверить ingress
kubectl describe ingress nginx -n default

# Проверить IAM роль
aws iam get-role --role-name ALB-<cluster-name>
```

### Проблема: Metrics недоступны

**Решение**:
```bash
# Перезапустить metrics-server
kubectl rollout restart deployment metrics-server -n kube-system

# Проверить логи
kubectl logs -n kube-system -l k8s-app=metrics-server

# Проверить сертификаты
kubectl get apiservice v1beta1.metrics.