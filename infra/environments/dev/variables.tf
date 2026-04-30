variable "aws_region" {
  type        = string
  default     = "us-west-1"
  description = "AWS region for all resources in this stack."
}

variable "eks_public_access_cidrs" {
  type        = list(string)
  default     = ["98.51.205.17/32"]
  description = "Public IPs allowed to call the EKS Kubernetes API (kubectl). Add CIDRs if your IP changes or you use CI."
}

variable "project" {
  type    = string
  default = "study-platform"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "kubernetes_version" {
  type        = string
  description = "Must be supported by EKS in var.aws_region."
  default     = "1.31"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "eks_node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "eks_node_desired_size" {
  type    = number
  default = 2
}

variable "eks_node_min_size" {
  type    = number
  default = 1
}

variable "eks_node_max_size" {
  type    = number
  default = 4
}

variable "eks_control_plane_log_types" {
  type        = list(string)
  default     = []
  description = "Optional CloudWatch log types for the EKS control plane, e.g. [\"api\", \"audit\"]."
}

variable "public_dns_domain" {
  type        = string
  default     = "charliesystems.ai"
  description = "Public Route53 zone for ACM + aliases (empty string to skip)."
}

variable "public_hosted_zone_id" {
  type        = string
  default     = "Z0712033I5GWDME6AGEP"
  description = "Route53 hosted zone ID for public_dns_domain. Set explicitly when duplicate hosted zones exist."
}

variable "create_route53_alb_aliases" {
  type        = bool
  default     = true
  description = "Create api/app/grafana A records to existing ALBs. Requires ALBs from kubectl ingresses. Set false if data.aws_lb lookups fail on first apply."
}

variable "public_https_api_alb_name" {
  type        = string
  default     = "study-platform-api"
  description = "ALB name for API ingress (must match ingress annotation)."
}

variable "public_https_frontend_alb_name" {
  type        = string
  default     = "study-platform-frontend"
  description = "ALB name for frontend ingress."
}

variable "public_https_grafana_alb_name" {
  type        = string
  default     = "study-platform-grafana"
  description = "ALB name for Grafana ingress."
}
