module "extract_lambda_function" {
    source = "terraform-aws-modules/lambda/aws"

    function_name = "extract-lambda"
    description = "Extract Lambda function"
    handler = "extract_lambda.lambda_handler"
    runtime = "python3.12"

    source_path = "../pipeline/extract/extract_lambda.py"

    create_role = false
    lambda_role = var.extract_lambda_role_arn

    timeout = 60
    memory_size = 256
    
    environment_variables = {
        EIA_API_KEY_SECRET_ARN = var.eia_secret_arn
        RAW_BUCKET             = var.raw_bucket_name
    }
    tags = {
        Name = "extract-lambda"
    }
}

module "transform_lambda_function" {
    source = "terraform-aws-modules/lambda/aws"

    function_name = "transform-lambda"
    description   = "Transform Lambda function"
    handler       = "transform_lambda.lambda_handler"
    runtime       = "python3.12"

    source_path = "../pipeline/transform/transform_lambda.py"

    create_role = false
    lambda_role = var.transform_lambda_role_arn

    layers = [var.pandas_layer_arn]
    
    timeout     = 60
    memory_size = 512

    environment_variables = {
        RAW_BUCKET       = var.raw_bucket_name
        PROCESSED_BUCKET = var.processed_bucket_name
    }

    tags = {
        Name = "transform-lambda"
    }
}

module "load_lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = "load-lambda"
  description   = "Load Lambda function"
  handler       = "load_lambda.lambda_handler"
  runtime       = "python3.12"
  source_path   = "../pipeline/load"
  timeout       = 60
  memory_size   = 512

  create_role = false
  lambda_role = var.load_lambda_role_arn

  layers = [var.pandas_layer_arn]

  environment_variables = {
    PROCESSED_BUCKET = var.processed_bucket_name
    DB_HOST          = var.db_host
    DB_PORT          = "5432"
    DB_NAME          = var.db_name
    DB_USER          = "load_lambda_user"
  }

  tags = { Name = "load-lambda" }
}