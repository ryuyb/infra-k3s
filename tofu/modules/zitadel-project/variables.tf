variable "name" {
  description = "Project name"
  type        = string
}

variable "org_id" {
  description = "ZITADEL organization ID"
  type        = string
}

variable "project_role_assertion" {
  description = "Whether to assert roles in the token"
  type        = bool
  default     = false
}

variable "project_role_check" {
  description = "Whether to check roles"
  type        = bool
  default     = false
}

variable "roles" {
  description = "Map of project roles"
  type = map(object({
    display_name = string
  }))
  default = {}
}

variable "grants" {
  description = "Map of user grants"
  type = map(object({
    user_id   = string
    role_keys = list(string)
  }))
  default = {}
}
