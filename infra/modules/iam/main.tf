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