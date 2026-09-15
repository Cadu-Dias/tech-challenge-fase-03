variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "cluster_name" {
  description = "Usado para as tags kubernetes.io/cluster/<name> exigidas pelo EKS e pelo ALB/NLB controller."
  type        = string
}
