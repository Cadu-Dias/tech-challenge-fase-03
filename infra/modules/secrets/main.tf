############################################
# Módulo secrets: gera credenciais com
# random_password, persiste em AWS Secrets
# Manager (auditoria/rotação) e materializa
# os Kubernetes Secrets consumidos pelos
# Deployments (substituindo os antigos
# `secret.template.yaml` preenchidos à mão).
############################################

resource "random_password" "service_api_key" {
  length  = 40
  special = false
}

resource "random_password" "auth_master_key" {
  length  = 40
  special = false
}

resource "kubernetes_namespace" "toggle" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/part-of" = "toggle-master"
    }
  }

  # A gestão do namespace é compartilhada com o ArgoCD (gitops/base). Evita
  # que o Terraform tente reverter labels/anotações adicionadas pelo sync.
  lifecycle {
    ignore_changes = [metadata[0].labels, metadata[0].annotations]
  }
}

locals {
  secrets_manager_payload = {
    auth = {
      DATABASE_URL = "postgres://${var.rds_master_username}:${var.rds_passwords["auth"]}@${var.rds_endpoints["auth"]}/${var.rds_database_names["auth"]}?sslmode=require"
      MASTER_KEY   = random_password.auth_master_key.result
    }
    flag = {
      DATABASE_URL = "postgres://${var.rds_master_username}:${var.rds_passwords["flag"]}@${var.rds_endpoints["flag"]}/${var.rds_database_names["flag"]}?sslmode=require"
    }
    targeting = {
      DATABASE_URL = "postgres://${var.rds_master_username}:${var.rds_passwords["targeting"]}@${var.rds_endpoints["targeting"]}/${var.rds_database_names["targeting"]}?sslmode=require"
    }
    evaluation = {
      SERVICE_API_KEY = random_password.service_api_key.result
      REDIS_ADDR      = "${var.redis_endpoint}:${var.redis_port}"
      AWS_SQS_URL     = var.sqs_queue_url
    }
    analytics = {
      AWS_SQS_URL        = var.sqs_queue_url
      AWS_DYNAMODB_TABLE = var.dynamodb_table_name
      AWS_REGION         = var.aws_region
    }
  }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = local.secrets_manager_payload

  name                    = "togglemaster/${var.environment}/${each.key}"
  recovery_window_in_days = 0

  tags = {
    Service = "${each.key}-service"
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = local.secrets_manager_payload

  secret_id     = aws_secretsmanager_secret.this[each.key].id
  secret_string = jsonencode(each.value)
}

resource "kubernetes_secret" "this" {
  for_each = local.secrets_manager_payload

  metadata {
    name      = "${each.key}-secret"
    namespace = kubernetes_namespace.toggle.metadata[0].name
  }

  data = each.value

  type = "Opaque"
}
