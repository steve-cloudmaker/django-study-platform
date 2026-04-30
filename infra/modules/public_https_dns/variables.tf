variable "public_dns_domain" {
  type        = string
  description = "Public DNS zone (e.g. charliesystems.ai) in Route53 in this account."
}

variable "api_subdomain" {
  type        = string
  default     = "api"
  description = "API hostname prefix (api.example.com)."
}

variable "app_subdomain" {
  type        = string
  default     = "app"
  description = "Frontend hostname prefix (app.example.com)."
}

variable "grafana_subdomain" {
  type        = string
  default     = "grafana"
  description = "Grafana hostname prefix (grafana.example.com)."
}

variable "api_alb_name" {
  type        = string
  description = "Existing ALB name for the API ingress (matches alb.ingress.kubernetes.io/load-balancer-name)."
}

variable "frontend_alb_name" {
  type        = string
  description = "Existing ALB name for the frontend ingress."
}

variable "grafana_alb_name" {
  type        = string
  description = "Existing ALB name for the Grafana ingress."
}

variable "create_route53_alb_aliases" {
  type        = bool
  default     = true
  description = "Create Route53 alias A records to ALBs. Requires ALBs to exist. Set false on first apply if data sources fail."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags for ACM certificate."
}
