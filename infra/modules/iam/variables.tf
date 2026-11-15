variable "eia_secret_arn" {
    description = "ARN of the Secrets Manager secret holding the EIA API key"
    type        = string
}

variable "raw_bucket_arn" {
    description = "ARN of the S3 bucket the extract Lambda writes raw data to"
    type        = string
}

variable "processed_bucket_arn" {
    description = "ARN of the S3 bucket the transform Lambda writes curated data to"
    type        = string
}

variable "db_resource_id" {
    description = "DB Resource ID"
    type        = string
}

variable "sns_topic_arn" {
    description = "SNS Topic ARN"
    type        = string
}