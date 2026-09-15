############################################
# Backend remoto: state em S3 (com lock
# nativo via `use_lockfile`, sem DynamoDB).
#
# O bucket é criado pela stack infra/bootstrap
# e informado aqui via variável de partial
# configuration (backend-config) para evitar
# hardcode do nome (que inclui o account id).
#
# Uso:
#   terraform init \
#     -backend-config="bucket=togglemaster-tfstate-<ACCOUNT_ID>" \
#     -backend-config="region=us-east-1"
############################################

terraform {
  backend "s3" {
    key          = "toggle-master/infra.tfstate"
    encrypt      = true
    use_lockfile = true
    # bucket e region são fornecidos via -backend-config (ver backend.hcl.example)
  }
}
