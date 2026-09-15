############################################
# Módulo ecr: um repositório por microsserviço,
# com scan automático de vulnerabilidades no
# push e lifecycle policy para não acumular
# imagens antigas indefinidamente.
############################################

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name                 = "toggle/${each.key}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = each.key
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Mantém apenas as 15 imagens mais recentes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 15
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
