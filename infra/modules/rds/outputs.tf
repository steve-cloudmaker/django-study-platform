output "endpoint" {
  value = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "engine_version" {
  value       = aws_db_instance.this.engine_version
  description = "Postgres engine version applied to the instance."
}

output "master_user_secret_arn" {
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
  description = "Secrets Manager ARN for master password (use in External Secrets or manual sync)."
}

output "security_group_id" {
  value = aws_security_group.rds.id
}
