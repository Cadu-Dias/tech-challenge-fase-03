############################################
# Módulo eks: cluster EKS + Node Group gerenciado.
#
# Restrição AWS Academy: não é permitido criar
# IAM Roles/Policies. A LabRole pré-existente é
# importada via data source e associada tanto ao
# cluster quanto ao node group (ela já contém as
# permissões necessárias: EKS, EC2, S3, DynamoDB,
# SQS, ECR etc.).
############################################

locals {
  name = "${var.project_name}-${var.environment}"
}

data "aws_iam_role" "lab_role" {
  name = var.lab_role_name
}

resource "aws_security_group" "cluster" {
  name        = "${local.name}-eks-cluster-sg"
  description = "Security group adicional do control plane do EKS"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-eks-cluster-sg"
  }
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = data.aws_iam_role.lab_role.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  tags = {
    Name = local.name
  }
}

# --- Launch Template para o Node Group ---
# Necessário para ajustar o hop-limit do IMDSv2 para 2, permitindo que os
# processos dentro dos pods (não apenas processos no namespace de rede do
# host) acessem as credenciais da LabRole via metadata (problema conhecido
# da Fase 2 documentado no README do projeto de microsserviços).
resource "aws_launch_template" "nodes" {
  name_prefix = "${local.name}-node-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name}-node"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.name}-ng"
  node_role_arn   = data.aws_iam_role.lab_role.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_group_desired_size
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
  }

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name = "${local.name}-ng"
  }

  depends_on = [aws_eks_cluster.this]
}
