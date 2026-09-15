variable "namespace" {
  type    = string
  default = "argocd"
}

variable "chart_version" {
  type = string
}

variable "gitops_repo_url" {
  type = string
}

variable "gitops_repo_path" {
  type = string
}

variable "gitops_target_revision" {
  type = string
}

variable "app_name" {
  type    = string
  default = "toggle-master"
}

variable "destination_namespace" {
  type    = string
  default = "toggle"
}

variable "cluster_name" {
  description = "Nome do cluster EKS, usado para gerar o kubeconfig temporário no apply do Application."
  type        = string
}

variable "aws_region" {
  type = string
}
