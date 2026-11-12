output "secret_arn" {
    value = aws_secretsmanager_secret.eia_api_key.arn
}