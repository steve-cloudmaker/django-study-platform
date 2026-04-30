variable "identifier" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Security groups allowed to connect to PostgreSQL (e.g. EKS node SG)."
}

variable "db_name" {
  type    = string
  default = "study"
}

variable "username" {
  type    = string
  default = "studyadmin"
}

variable "engine_major_version" {
  type        = string
  default     = "16"
  description = "Major Postgres line when engine_version is null (latest minor in this region/account)."
}

variable "engine_version" {
  type        = string
  default     = null
  description = "Pin to an exact Postgres x.y (e.g. 16.6). Leave null to auto-resolve latest minor for engine_major_version."
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "tags" {
  type    = map(string)
  default = {}
}
