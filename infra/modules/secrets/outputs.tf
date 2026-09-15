output "namespace" {
  value = kubernetes_namespace.toggle.metadata[0].name
}

output "service_api_key" {
  value     = random_password.service_api_key.result
  sensitive = true
}
