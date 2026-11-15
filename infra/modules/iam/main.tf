data "aws_iam_policy_document" "extract_secrets_access" {
    statement {
        effect = "Allow"
        actions = ["secretsmanager:GetSecretValue"]
        resources = [var.eia_secret_arn]
    }
}

resource "aws_iam_role_policy" "extract_secrets" {
    name = "extract-secrets-access"
    role = aws_iam_role.extract_lambda_role.id 
    policy = data.aws_iam_policy_document.extract_secrets_access.json
}

resource "aws_iam_role" "extract_lambda_role" {
    name = "extract-lambda-role"

    assume_role_policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "lambda.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "extract_basic_execution" {
    role = aws_iam_role.extract_lambda_role.id
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "extract_s3_write" {
    statement {
        effect    = "Allow"
        actions   = ["s3:PutObject"]
        resources = ["${var.raw_bucket_arn}/raw/*"]
    }
}

resource "aws_iam_role_policy" "extract_s3_write" {
    name  = "extract-s3-write-access"
    role  = aws_iam_role.extract_lambda_role.id
    policy = data.aws_iam_policy_document.extract_s3_write.json
}

resource "aws_iam_role" "transform_lambda_role" {
    name = "transform-lambda-role"

    assume_role_policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": { 
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }]
    })
}

resource "aws_iam_role_policy_attachment" "transform_basic_execution" {
    role       = aws_iam_role.transform_lambda_role.id
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "transform_s3_access" {
    statement {
        effect   = "Allow"
        actions  = ["s3:GetObject", "s3:ListBucket"]
        resources = [var.raw_bucket_arn, "${var.raw_bucket_arn}/raw/*"]
    }
    statement {
        effect   = "Allow"
        actions  = ["s3:PutObject"]
        resources = ["${var.processed_bucket_arn}/processed/*"]
    }
}

resource "aws_iam_role_policy" "transform_s3_access" {
    name   = "transform-s3-access"
    role   = aws_iam_role.transform_lambda_role.id
    policy = data.aws_iam_policy_document.transform_s3_access.json
}

resource "aws_iam_role" "load_lambda_role" {
    name = "load-lambda-role"
    assume_role_policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }]
    })
}

resource "aws_iam_role_policy_attachment" "load_basic_execution" {
    role       = aws_iam_role.load_lambda_role.id
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "load_access" {
    statement {
        effect    = "Allow"
        actions   = ["s3:GetObject", "s3:ListBucket"]
        resources = [var.processed_bucket_arn, "${var.processed_bucket_arn}/processed/*"]
    }
    statement {
        effect    = "Allow"
        actions   = ["rds-db:connect"]
        resources = ["arn:aws:rds-db:us-east-1:${data.aws_caller_identity.current.account_id}:dbuser:${var.db_resource_id}/load_lambda_user"]
    }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "load_access" {
    name   = "load-access"
    role   = aws_iam_role.load_lambda_role.id
    policy = data.aws_iam_policy_document.load_access.json
}

