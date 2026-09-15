variable "aws_region" {
  description = "Região AWS onde a infraestrutura será provisionada."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto, usado como prefixo/tag em todos os recursos."
  type        = string
  default     = "togglemaster"
}

variable "environment" {
  description = "Nome do ambiente (ex.: prod, staging)."
  type        = string
  default     = "prod"
}

# --- Networking ---

variable "vpc_cidr" {
  description = "CIDR block da VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "Availability Zones utilizadas (2 AZs para reduzir custo de NAT Gateway)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "single_nat_gateway" {
  description = "Se true, cria apenas 1 NAT Gateway (economia de custo) em vez de 1 por AZ."
  type        = bool
  default     = true
}

# --- IAM (AWS Academy) ---

variable "lab_role_name" {
  description = "Nome da IAM Role pré-existente (LabRole) usada para o EKS e Node Groups no AWS Academy. Em conta pessoal, defina para uma role própria ou adapte os módulos para criar roles via Terraform."
  type        = string
  default     = "LabRole"
}

# --- EKS ---

variable "cluster_name" {
  description = "Nome do cluster EKS."
  type        = string
  default     = "togglemaster-eks"
}

variable "kubernetes_version" {
  description = "Versão do Kubernetes do cluster EKS."
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "Tipos de instância EC2 usados pelo Node Group gerenciado."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  type    = number
  default = 3
}

variable "node_group_min_size" {
  type    = number
  default = 2
}

variable "node_group_max_size" {
  type    = number
  default = 6
}

# --- Bancos de dados (RDS) ---

variable "rds_instance_class" {
  description = "Classe de instância para as 3 instâncias RDS PostgreSQL."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  type    = number
  default = 20
}

variable "rds_engine_version" {
  description = "Versão do PostgreSQL nas instâncias RDS."
  type        = string
  default     = "16.4"
}

variable "rds_databases" {
  description = "Bancos RDS a provisionar: um por microsserviço com estado relacional."
  type        = set(string)
  default     = ["auth", "flag", "targeting"]
}

# --- ElastiCache (Redis) ---

variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}

# --- DynamoDB ---

variable "dynamodb_table_name" {
  type    = string
  default = "ToggleMasterAnalytics"
}

# --- SQS ---

variable "sqs_queue_name" {
  type    = string
  default = "toggle-events"
}

# --- ECR ---

variable "ecr_repositories" {
  description = "Repositórios ECR a criar, um por microsserviço."
  type        = list(string)
  default     = ["auth-service", "flag-service", "targeting-service", "evaluation-service", "analytics-service"]
}

# --- ArgoCD ---

variable "install_argocd" {
  description = "Se true, instala o ArgoCD via Helm no cluster EKS criado."
  type        = bool
  default     = true
}

variable "argocd_chart_version" {
  type    = string
  default = "7.7.3"
}

variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "gitops_repo_url" {
  description = "URL do repositório Git (este monorepo) contendo os manifestos em gitops/overlays/prod, usado pela Application do ArgoCD."
  type        = string
  default     = "https://github.com/Cadu-Dias/tech-challenge-fase-03.git"
}

variable "gitops_repo_path" {
  type    = string
  default = "gitops/overlays/prod"
}

variable "gitops_target_revision" {
  type    = string
  default = "main"
}
