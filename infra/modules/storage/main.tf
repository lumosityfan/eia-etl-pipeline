resource "random_pet" "eia_etl_raw_bucket_name" {
    prefix = "eia-etl-raw"
    length = 4
}

resource "random_pet" "eia_etl_processed_bucket_name" {
    prefix = "eia-etl-processed"
    length = 4
}

resource "aws_s3_bucket" "eia_etl_raw" {
    bucket = random_pet.eia_etl_raw_bucket_name.id

    tags = {
        Name = "Raw EIA ETL Data"
        Environment = "Dev"
    }
}

resource "aws_s3_bucket" "eia_etl_processed" {
    bucket = random_pet.eia_etl_processed_bucket_name.id

    tags = {
        Name = "Processed EIA ETL Data"
        Environment = "Dev"
    }
}

resource "aws_s3_bucket_lifecycle_configuration" "raw_automatic_delete" {
    bucket = aws_s3_bucket.eia_etl_raw.id

    rule {
        id = "expire-objects-on-specific-time-length"
        status = "Enabled"

        # Leave filter empty to apply to the entire bucket
        filter {}

        expiration {
            days = 90
        }
    }
}