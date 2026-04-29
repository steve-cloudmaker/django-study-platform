variable "aws_region" {
  type    = string
  default = "us-east-1"
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
