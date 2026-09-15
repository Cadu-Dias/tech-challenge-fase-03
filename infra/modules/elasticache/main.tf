############################################
# Módulo elasticache: cluster Redis usado
# como cache pelo evaluation-service.
############################################

locals {
  name = "${var.project_name}-${var.environment}"
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${local.name}-redis-subnets"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "redis" {
  name        = "${local.name}-redis-sg"
  description = "Permite acesso Redis (6379) somente dos nos do EKS"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-redis-sg"
  }
}

resource "aws_security_group_rule" "redis_ingress" {
  # count usa apenas o tamanho (estático) da lista; o valor do SG de origem
  # (desconhecido até o apply) é usado como atributo, não como chave.
  count = length(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = var.allowed_security_group_ids[count.index]
}

resource "aws_elasticache_cluster" "this" {
  cluster_id         = "${local.name}-redis"
  engine             = "redis"
  engine_version     = "7.1"
  node_type          = var.node_type
  num_cache_nodes    = 1
  port               = 6379
  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]
  apply_immediately  = true

  tags = {
    Name = "${local.name}-redis"
  }
}
