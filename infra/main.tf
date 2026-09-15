############################################
# Stack principal: orquestra todos os módulos
# de infraestrutura do ToggleMaster.
############################################

module "network" {
  source = "./modules/network"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  azs                = var.azs
  single_nat_gateway = var.single_nat_gateway
  cluster_name       = var.cluster_name
}

module "eks" {
  source = "./modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  public_subnet_ids  = module.network.public_subnet_ids
  lab_role_name      = var.lab_role_name

  node_instance_types     = var.node_instance_types
  node_group_desired_size = var.node_group_desired_size
  node_group_min_size     = var.node_group_min_size
  node_group_max_size     = var.node_group_max_size
}

module "rds" {
  source = "./modules/rds"

  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]
  databases                  = var.rds_databases
  instance_class             = var.rds_instance_class
  allocated_storage          = var.rds_allocated_storage
  engine_version             = var.rds_engine_version
}

module "elasticache" {
  source = "./modules/elasticache"

  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]
  node_type                  = var.redis_node_type
}

module "dynamodb" {
  source = "./modules/dynamodb"

  table_name = var.dynamodb_table_name
}

module "sqs" {
  source = "./modules/sqs"

  queue_name = var.sqs_queue_name
}

module "ecr" {
  source = "./modules/ecr"

  repositories = var.ecr_repositories
}

module "secrets" {
  source = "./modules/secrets"

  project_name        = var.project_name
  environment         = var.environment
  namespace           = "toggle"
  rds_endpoints       = module.rds.endpoints
  rds_addresses       = module.rds.addresses
  rds_database_names  = module.rds.database_names
  rds_master_username = module.rds.master_username
  rds_passwords       = module.rds.passwords
  redis_endpoint      = module.elasticache.endpoint
  redis_port          = module.elasticache.port
  sqs_queue_url       = module.sqs.queue_url
  dynamodb_table_name = module.dynamodb.table_name
  aws_region          = var.aws_region

  depends_on = [module.eks]
}

module "argocd" {
  source = "./modules/argocd"
  count  = var.install_argocd ? 1 : 0

  chart_version          = var.argocd_chart_version
  namespace              = var.argocd_namespace
  gitops_repo_url        = var.gitops_repo_url
  gitops_repo_path       = var.gitops_repo_path
  gitops_target_revision = var.gitops_target_revision
  destination_namespace  = module.secrets.namespace
  cluster_name           = module.eks.cluster_name
  aws_region             = var.aws_region
  gitops_repo_token      = var.gitops_repo_token

  depends_on = [module.eks, module.secrets]
}

module "ingress_nginx" {
  source = "./modules/ingress_nginx"

  chart_version = var.ingress_nginx_chart_version

  depends_on = [module.eks]
}
