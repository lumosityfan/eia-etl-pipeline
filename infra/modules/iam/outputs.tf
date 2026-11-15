output "extract_lambda_role_arn" {
    value = aws_iam_role.extract_lambda_role.arn
}

output "transform_lambda_role_arn" {
    value = aws_iam_role.transform_lambda_role.arn
}

output "load_lambda_role_arn" {
    value = aws_iam_role.load_lambda_role.arn
}