variable "name_prefix" {
  type = string
}

variable "cluster_oidc_issuer_url" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "sqs_queue_arn" {
  type = string
}

variable "k8s_namespace" {
  type    = string
  default = "default"
}

variable "api_service_account" {
  type    = string
  default = "api"
}

variable "worker_service_account" {
  type    = string
  default = "worker"
}

variable "alb_controller_namespace" {
  type    = string
  default = "kube-system"
}

variable "alb_controller_service_account" {
  type    = string
  default = "aws-load-balancer-controller"
}

variable "tags" {
  type    = map(string)
  default = {}
}
