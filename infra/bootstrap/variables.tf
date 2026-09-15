variable "aws_region" {
  description = "Região AWS onde o bucket de state será criado."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Nome do bucket S3 de state. Se vazio, é derivado do account id."
  type        = string
  default     = ""
}
