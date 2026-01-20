variable "name" {
  description = "Application and provider name"
  type        = string
}

variable "slug" {
  description = "Application slug"
  type        = string
}

variable "external_host" {
  description = "External URL users access"
  type        = string
}

variable "internal_host" {
  description = "Internal URL to proxy to (optional for forward_single mode)"
  type        = string
  default     = ""
}

variable "authorization_flow_slug" {
  description = "Authorization flow slug"
  type        = string
  default     = "default-provider-authorization-implicit-consent"
}

variable "invalidation_flow_slug" {
  description = "Invalidation flow slug"
  type        = string
  default     = "default-provider-invalidation-flow"
}

variable "mode" {
  description = "Proxy mode: proxy or forward_single or forward_domain"
  type        = string
  default     = "forward_single"
}

variable "group" {
  description = "Application group for UI"
  type        = string
  default     = ""
}

variable "meta_launch_url" {
  description = "Application launch URL"
  type        = string
  default     = ""
}

variable "open_in_new_tab" {
  description = "Open application in new tab"
  type        = bool
  default     = true
}
