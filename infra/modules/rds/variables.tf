variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups autorizados a se conectar às instâncias RDS na porta 5432 (ex.: SG dos nós do EKS)."
  type        = list(string)
}

variable "databases" {
  description = "Conjunto de nomes lógicos de banco (um por microsserviço), usado para nomear as 3 instâncias RDS."
  type        = set(string)
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "engine_version" {
  type = string
}

variable "master_username" {
  type    = string
  default = "toggle"
}
