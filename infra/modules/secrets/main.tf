resource "aws_secretsmanager_secret" "eia_api_key" {
    name        = "eia-etl/eia-api-key"
    description = "API key for the EIA energy data API used by the extract Lambda"
    recovery_window_in_days = 0
}
