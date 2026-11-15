module "storage" {
  source = "./modules/storage"
}

module "compute" {
  source                    = "./modules/compute"
  eia_secret_arn            = module.secrets.secret_arn
  raw_bucket_name           = module.storage.raw_bucket_name
  extract_lambda_role_arn   = module.iam.extract_lambda_role_arn
  processed_bucket_name     = module.storage.processed_bucket_name
  transform_lambda_role_arn = module.iam.transform_lambda_role_arn
  pandas_layer_arn          = var.pandas_layer_arn
  load_lambda_role_arn      = module.iam.load_lambda_role_arn
  db_host                   = module.database.db_host
  db_name                   = module.database.db_name
  sns_topic_arn             = module.messaging.topic_arn
}

module "iam" {
  source               = "./modules/iam"
  eia_secret_arn       = module.secrets.secret_arn
  raw_bucket_arn       = module.storage.raw_bucket_arn
  processed_bucket_arn = module.storage.processed_bucket_arn
  db_resource_id       = module.database.db_resource_id
  sns_topic_arn        = module.messaging.topic_arn
}

module "database" {
  source = "./modules/database"
}

module "secrets" {
  source = "./modules/secrets"
}

module "messaging" {
  source             = "./modules/messaging"
  notification_email = var.notification_email
}