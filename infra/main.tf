module "storage" {
  source = "./modules/storage"
}

module "compute" {
  source                  = "./modules/compute"
  eia_secret_arn          = module.secrets.secret_arn
  raw_bucket_name         = module.storage.raw_bucket_name
  extract_lambda_role_arn = module.iam.extract_lambda_role_arn
}

module "iam" {
  source         = "./modules/iam"
  eia_secret_arn = module.secrets.secret_arn
  raw_bucket_arn = module.storage.raw_bucket_arn
}

module "secrets" {
  source = "./modules/secrets"
}