variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "namespace" {
  type    = string
  default = "toggle"
}

variable "rds_endpoints" {
  description = "Mapa banco -> endpoint (host:port)."
  type        = map(string)
}

variable "rds_addresses" {
  description = "Mapa banco -> host (sem porta)."
  type        = map(string)
}

variable "rds_database_names" {
  type = map(string)
}

variable "rds_master_username" {
  type = string
}

variable "rds_passwords" {
  type      = map(string)
  sensitive = true
}

variable "redis_endpoint" {
  type = string
}

variable "redis_port" {
  type = number
}

variable "sqs_queue_url" {
  type = string
}

variable "dynamodb_table_name" {
  type = string
}

variable "aws_region" {
  type = string
}
