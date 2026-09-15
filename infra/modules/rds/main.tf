############################################
# Módulo rds: N instâncias PostgreSQL (uma
# por banco lógico em var.databases), todas
# em subnets privadas, acessíveis apenas a
# partir do(s) security group(s) informado(s)
# (nós do EKS).
############################################

locals {
  name = "${var.project_name}-${var.environment}"
}

resource "random_password" "master" {
  for_each = var.databases

  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-rds-subnets"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${local.name}-rds-subnets"
  }
}

resource "aws_security_group" "rds" {
  for_each = var.databases

  name        = "${local.name}-rds-${each.key}-sg"
  description = "Permite acesso PostgreSQL (5432) somente dos nós do EKS ao banco ${each.key}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-rds-${each.key}-sg"
  }
}

resource "aws_security_group_rule" "rds_ingress" {
  # Chaves estáticas (nomes dos bancos); o(s) SG(s) de origem são resolvidos
  # em tempo de apply, mas como valor, não como chave do for_each.
  for_each = var.databases

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds[each.key].id
  source_security_group_id = var.allowed_security_group_ids[0]
}

resource "aws_db_instance" "this" {
  for_each = var.databases

  identifier     = "${local.name}-${each.key}"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage      = var.allocated_storage
  storage_type           = "gp3"
  storage_encrypted      = true
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds[each.key].id]

  db_name  = "${each.key}_db"
  username = var.master_username
  password = random_password.master[each.key].result

  multi_az                = false
  publicly_accessible     = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1
  apply_immediately       = true

  tags = {
    Name    = "${local.name}-${each.key}"
    Service = "${each.key}-service"
  }
}
