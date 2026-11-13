variable "eia_secret_arn" {
    description = "ARN of the Secrets Manager secret holding the EIA API key"
    type = string
}

variable "raw_bucket_arn" {
    description = "ARN of the S3 bucket the extract Lambda writes raw data to"
    type        = string
}