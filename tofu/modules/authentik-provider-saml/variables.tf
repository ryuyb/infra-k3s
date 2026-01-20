variable "name" {
  description = "Application and provider name"
  type        = string
}

variable "slug" {
  description = "Application slug"
  type        = string
}

variable "acs_url" {
  description = "SAML Assertion Consumer Service URL"
  type        = string
}

variable "issuer" {
  description = "SAML issuer (defaults to authentik)"
  type        = string
  default     = null
}

variable "audience" {
  description = "SAML audience"
  type        = string
  default     = ""
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
