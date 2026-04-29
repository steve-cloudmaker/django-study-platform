variable "bucket_name_prefix" {
  type        = string
  description = "Globally unique prefix; a random suffix is appended."
}

variable "tags" {
  type    = map(string)
  default = {}
}
