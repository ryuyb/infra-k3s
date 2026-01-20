variable "name" {
  description = "Application and provider name"
  type        = string
}

variable "slug" {
  description = "Application slug"
  type        = string
}

variable "base_dn" {
  description = "LDAP base DN"
  type        = string
}

variable "bind_flow_slug" {
  description = "LDAP bind flow slug"
  type        = string
  default     = "default-authentication-flow"
}

variable "search_group" {
  description = "Group for LDAP search (optional)"
  type        = string
  default     = null
}

variable "group" {
  description = "Application group for UI"
  type        = string
  default     = ""
}
