variable "zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "records" {
  description = "Map of DNS records to create"
  type = map(object({
    type    = string
    value   = string
    ttl     = optional(number)
    proxied = optional(bool)
    comment = optional(string)
  }))
  default = {}
}

variable "default_ttl" {
  description = "Default TTL for records (1 = auto)"
  type        = number
  default     = 1
}

variable "default_proxied" {
  description = "Default proxied setting"
  type        = bool
  default     = true
}
