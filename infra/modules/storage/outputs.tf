output "raw_bucket_name" {
    value = aws_s3_bucket.eia_etl_raw.id
}

output "raw_bucket_arn" {
    value = aws_s3_bucket.eia_etl_raw.arn
}

output "processed_bucket_name" {
    value = aws_s3_bucket.eia_etl_processed.id
}

output "processed_bucket_arn" {
    value = aws_s3_bucket.eia_etl_processed.arn
}