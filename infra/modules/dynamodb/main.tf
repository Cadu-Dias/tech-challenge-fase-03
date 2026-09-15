############################################
# Módulo dynamodb: tabela ToggleMasterAnalytics
# usada pelo analytics-service para armazenar
# os eventos de avaliação consumidos da SQS.
############################################

resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  tags = {
    Name = var.table_name
  }
}
