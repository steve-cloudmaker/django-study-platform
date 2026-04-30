output "acm_certificate_arn" {
  value       = aws_acm_certificate_validation.ingress.certificate_arn
  description = "ACM certificate ARN for ALB Ingress (wildcard + apex)."
}

output "api_fqdn" {
  value = local.api_fqdn
}

output "app_fqdn" {
  value = local.app_fqdn
}

output "grafana_fqdn" {
  value = local.grafana_fqdn
}

output "api_https_url" {
  value = "https://${local.api_fqdn}"
}

output "app_https_url" {
  value = "https://${local.app_fqdn}"
}

output "grafana_https_url" {
  value = "https://${local.grafana_fqdn}"
}
