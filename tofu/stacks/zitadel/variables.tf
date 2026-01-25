variable "zitadel_domain" {
  type        = string                           # The type of the variable, in this case a string
  description = "The domain of zitadel instance" # Description of what this variable represents
}

variable "zitadel_access_token" {
  type = string
}

variable "zitadel_default_org_id" {
  type        = string
  description = "The org id"
}

variable "zitadel_default_user_id" {
  type = string
}

variable "argocd_domain" {
  type = string
}

variable "oauth2_proxy_domain" {
  type = string
}
