output "endpoints" {
  description = "Mapa banco -> endpoint (host:port) da instância RDS."
  value       = { for k, v in aws_db_instance.this : k => v.endpoint }
}

output "addresses" {
  description = "Mapa banco -> hostname (sem porta) da instância RDS."
  value       = { for k, v in aws_db_instance.this : k => v.address }
}

output "database_names" {
  value = { for k, v in aws_db_instance.this : k => v.db_name }
}

output "master_username" {
  value = var.master_username
}

output "passwords" {
  description = "Mapa banco -> senha gerada (sensível)."
  value       = { for k, v in random_password.master : k => v.result }
  sensitive   = true
}
