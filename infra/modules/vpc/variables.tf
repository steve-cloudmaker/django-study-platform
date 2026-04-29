variable "name" {
  type        = string
  description = "Prefix for resource names (e.g. study-dev)."
}

variable "cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC IPv4 CIDR."
}

variable "az_count" {
  type        = number
  default     = 2
  description = "Number of availability zones (subnets per tier)."
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name for subnet tags (ALB controller / shared cluster tag)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags for the VPC and its resources."
}
