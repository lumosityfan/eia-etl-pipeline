output "db_host" {
    value = aws_db_instance.eia_etl.address
}

output "db_name" {
    value = aws_db_instance.eia_etl.db_name
}

output "db_resource_id" {
    value = aws_db_instance.eia_etl.resource_id
}

output "master_user_secret_arn" {
    value = aws_db_instance.eia_etl.master_user_secret[0].secret_arn
}