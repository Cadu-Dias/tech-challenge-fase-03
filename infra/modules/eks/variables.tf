variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "lab_role_name" {
  description = "Nome da IAM Role pré-existente (LabRole) usada tanto pelo cluster EKS quanto pelo Node Group (restrição AWS Academy: não é possível criar IAM Roles/Policies)."
  type        = string
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_group_desired_size" {
  type = number
}

variable "node_group_min_size" {
  type = number
}

variable "node_group_max_size" {
  type = number
}
