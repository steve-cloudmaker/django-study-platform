output "api_role_arn" {
  value = aws_iam_role.api.arn
}

output "worker_role_arn" {
  value = aws_iam_role.worker.arn
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}

output "grafana_role_arn" {
  value       = aws_iam_role.grafana.arn
  description = "Annotate monitoring/grafana SA with eks.amazonaws.com/role-arn for CloudWatch datasource."
}
