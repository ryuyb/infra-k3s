variable "name" {
  description = "Application and provider name"
  type        = string
}

variable "slug" {
  description = "Application slug"
  type        = string
}

variable "client_id" {
  description = "OAuth2 client ID"
  type        = string
}

variable "client_secret" {
  description = "OAuth2 client secret (auto-generated if null)"
  type        = string
  default     = null
  sensitive   = true
}

variable "redirect_uris" {
  description = "Allowed redirect URIs"
  type = list(object({
    url           = string
    matching_mode = optional(string, "strict")
  }))
}

variable "authorization_flow_slug" {
  description = "Authorization flow slug"
  type        = string
  default     = "default-provider-authorization-implicit-consent"
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
