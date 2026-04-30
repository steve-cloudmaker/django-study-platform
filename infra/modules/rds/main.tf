data "aws_rds_engine_version" "resolved" {
  count = var.engine_version == null ? 1 : 0

  engine  = "postgres"
  version = var.engine_major_version
  latest  = true
}

locals {
  # Prefer full version string from AWS; fall back to `version` for older provider schemas.
  engine_version_effective = coalesce(
    var.engine_version,
    try(data.aws_rds_engine_version.resolved[0].version_actual, data.aws_rds_engine_version.resolved[0].version),
  )
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, { Name = "${var.identifier}-subnet" })
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.identifier}-rds-"
  vpc_id      = var.vpc_id
  description = "PostgreSQL from EKS nodes"

  ingress {
    description     = "PostgreSQL from EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier = var.identifier

  engine               = "postgres"
  engine_version       = local.engine_version_effective
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [
    aws_security_group.rds.id,
  ]

  db_name  = var.db_name
  username = var.username

  publicly_accessible     = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1

  manage_master_user_password = true

  tags = var.tags
}
