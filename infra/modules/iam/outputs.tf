output "api_role_arn" {
  value = aws_iam_role.api.arn
}

output "worker_role_arn" {
  value = aws_iam_role.worker.arn
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}
