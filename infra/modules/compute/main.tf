module "lambda_function" {
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