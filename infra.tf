module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
}

module "rds" {
  source = "./modules/rds"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  db_security_group_id = module.vpc.db_security_group_id
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  db_instance_class = var.db_instance_class
}

module "ec2" {
  source = "./modules/ec2"

  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  public_subnet_ids    = module.vpc.public_subnet_ids
  private_subnet_ids   = module.vpc.private_subnet_ids
  app_security_group_id = module.vpc.app_security_group_id
  instance_type        = var.app_instance_type
  ssh_key_name         = var.ssh_key_name
  allowed_ssh_cidrs    = var.allowed_ssh_cidrs
  db_endpoint          = module.rds.db_endpoint
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  s3_bucket_name       = module.s3.bucket_name
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  monitoring_security_group_id = module.vpc.monitoring_security_group_id
  instance_type           = var.monitoring_instance_type
  ssh_key_name            = var.ssh_key_name
  allowed_ssh_cidrs       = var.allowed_ssh_cidrs
  app_instance_ips        = module.ec2.app_instance_private_ips
}
