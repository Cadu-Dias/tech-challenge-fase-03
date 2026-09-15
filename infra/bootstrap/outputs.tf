output "state_bucket_name" {
  description = "Nome do bucket S3 a ser usado no backend remoto das demais stacks."
  value       = aws_s3_bucket.tfstate.bucket
}

output "state_bucket_arn" {
  value = aws_s3_bucket.tfstate.arn
}
