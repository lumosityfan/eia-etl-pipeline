data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

resource "aws_db_subnet_group" "eia_etl" {
    name       = "eia-etl-db-subnet-group"
    subnet_ids = data.aws_subnets.default.ids
}

resource "aws_security_group" "rds" {
    name   = "eia-etl-rds-sg"
    vpc_id = data.aws_vpc.default.id

    ingress {
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] # non-VPC Lambda has no fixed IP to allow-list; IAM auth + forced SSL is the real gate
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_db_parameter_group" "eia_etl" {
    name   = "eia-etl-postgres-params"
    family = "postgres16"

    parameter {
        name  = "rds.force_ssl"
        value = "1"
    }
}

resource "aws_db_instance" "eia_etl" {
    identifier     = "eia-etl-postgres"
    engine         = "postgres"
    engine_version = "16.4"

    instance_class      = "db.t3.micro"
    allocated_storage   = 20
    storage_type        = "gp2"
    db_name             = "eia_etl"
    username            = "postgres"
    manage_master_user_password = true # AWS creates and stores the master passwd in Secrets Manager for you

    iam_database_authentication_enabled = true
    publicly_accessible                 = true
    vpc_security_group_ids              = [aws_security_group.rds.id]
    db_subnet_group_name                = aws_db_subnet_group.eia_etl.name
    parameter_group_name                = aws_db_parameter_group.eia_etl.name

    skip_final_snapshot = true
    apply_immediately   = true

    tags = { Name = "eia-etl-postgres" }
}