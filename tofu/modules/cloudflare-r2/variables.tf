variable "account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "bucket_name" {
  description = "R2 bucket name"
  type        = string
}

variable "location" {
  description = "R2 bucket location (apac, eeur, enam, weur, wnam)"
  type        = string
  default     = "apac"
}
