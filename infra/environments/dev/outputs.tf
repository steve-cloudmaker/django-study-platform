output "aws_region" {
  value = var.aws_region
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "submissions_bucket" {
  value = module.s3_submissions.bucket_id
}

output "submissions_bucket_arn" {
  value = module.s3_submissions.bucket_arn
}

output "submissions_queue_url" {
  value = module.sqs_submissions.queue_url
}

output "submissions_queue_arn" {
  value = module.sqs_submissions.queue_arn
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "rds_port" {
  value = module.rds.port
}

output "rds_db_name" {
  value = module.rds.db_name
}

output "rds_engine_version" {
  value       = module.rds.engine_version
  description = "Resolved Postgres engine version on RDS."
}

output "rds_master_user_secret_arn" {
  value       = module.rds.master_user_secret_arn
  sensitive   = true
  description = "Fetch credentials from Secrets Manager for Kubernetes secrets."
}

output "api_role_arn" {
  value = module.iam_irsa.api_role_arn
}

output "worker_role_arn" {
  value = module.iam_irsa.worker_role_arn
}

output "alb_controller_role_arn" {
  value = module.iam_irsa.alb_controller_role_arn
}

output "public_acm_certificate_arn" {
  value       = length(module.public_https) > 0 ? module.public_https[0].acm_certificate_arn : ""
  description = "ACM ARN for ALB HTTPS. Run scripts/apply-acm-certificate-to-ingress.sh after kubectl apply ingresses."
}

output "public_api_https_url" {
  value       = length(module.public_https) > 0 ? module.public_https[0].api_https_url : ""
  description = "HTTPS URL for API after DNS propagates."
}

output "public_app_https_url" {
  value       = length(module.public_https) > 0 ? module.public_https[0].app_https_url : ""
  description = "HTTPS URL for frontend."
}

output "public_grafana_https_url" {
  value       = length(module.public_https) > 0 ? module.public_https[0].grafana_https_url : ""
  description = "HTTPS URL for Grafana."
}
