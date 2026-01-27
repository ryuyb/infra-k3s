variable "zitadel_domain" {
  type        = string
  description = "The domain of zitadel instance"
  validation {
    condition     = can(regex("^https://", var.zitadel_domain))
    error_message = "ZITADEL domain must start with https://"
  }
}

variable "zitadel_access_token" {
  type        = string
  description = "ZITADEL API access token"
  sensitive   = true
}

variable "zitadel_default_org_id" {
  type        = string
  description = "The default organization ID"
}

variable "zitadel_default_user_id" {
  type        = string
  description = "The default user ID for grants"
}

variable "argocd_domain" {
  type        = string
  description = "ArgoCD domain URL"
  validation {
    condition     = can(regex("^https://", var.argocd_domain))
    error_message = "ArgoCD domain must start with https://"
  }
}

variable "oauth2_proxy_domain" {
  type        = string
  description = "OAuth2 Proxy domain URL"
  validation {
    condition     = can(regex("^https://", var.oauth2_proxy_domain))
    error_message = "OAuth2 Proxy domain must start with https://"
  }
}

variable "vaultwarden_domain" {
  type        = string
  description = "Vaultwarden domain URL"
  validation {
    condition     = can(regex("^https://", var.vaultwarden_domain))
    error_message = "Vaultwarden domain must start with https://"
  }
}
