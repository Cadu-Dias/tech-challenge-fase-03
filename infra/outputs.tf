output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Comando para configurar o kubectl local após o apply."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "rds_endpoints" {
  value = module.rds.endpoints
}

output "redis_endpoint" {
  value = module.elasticache.endpoint
}

output "sqs_queue_url" {
  value = module.sqs.queue_url
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "argocd_namespace" {
  value = var.install_argocd ? module.argocd[0].namespace : null
}

output "argocd_port_forward_command" {
  description = "Comando para acessar a UI do ArgoCD localmente."
  value       = var.install_argocd ? "kubectl port-forward svc/argocd-server -n ${var.argocd_namespace} 8080:443" : null
}
