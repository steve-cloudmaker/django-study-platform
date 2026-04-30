variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type        = string
  description = "EKS control plane version (pin to a version supported in your region)."
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets for worker nodes and control plane (MVP: same subnets)."
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "cluster_enabled_log_types" {
  type        = list(string)
  default     = []
  description = "Optional: e.g. [\"api\", \"audit\"] — empty disables extra control plane logs (simplest)."
}

variable "cluster_endpoint_public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public Kubernetes API endpoint (kubectl). Nodes use the private endpoint when enabled."
}

variable "tags" {
  type    = map(string)
  default = {}
}
