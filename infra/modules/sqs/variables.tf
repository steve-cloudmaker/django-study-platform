variable "name_prefix" {
  type        = string
  description = "Prefix for queue names (e.g. study-dev)."
}

variable "visibility_timeout_seconds" {
  type        = number
  default     = 300
  description = "Tune to max expected processing time for workers."
}

variable "max_receive_count" {
  type    = number
  default = 5
}

variable "tags" {
  type    = map(string)
  default = {}
}
