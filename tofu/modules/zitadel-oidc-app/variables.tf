variable "name" {
  description = "OIDC application name"
  type        = string
}

variable "org_id" {
  description = "ZITADEL organization ID"
  type        = string
}

variable "project_id" {
  description = "ZITADEL project ID"
  type        = string
}

variable "app_type" {
  description = "OIDC application type"
  type        = string
  default     = "OIDC_APP_TYPE_WEB"
}

variable "response_types" {
  description = "OIDC response types"
  type        = list(string)
  default     = ["OIDC_RESPONSE_TYPE_CODE"]
}

variable "grant_types" {
  description = "OIDC grant types"
  type        = list(string)
  default     = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"]
}

variable "auth_method_type" {
  description = "OIDC authentication method type"
  type        = string
  default     = "OIDC_AUTH_METHOD_TYPE_BASIC"
}

variable "redirect_uris" {
  description = "OIDC redirect URIs"
  type        = list(string)
}

variable "post_logout_redirect_uris" {
  description = "OIDC post logout redirect URIs"
  type        = list(string)
  default     = []
}

variable "access_token_type" {
  description = "OIDC access token type"
  type        = string
  default     = "OIDC_TOKEN_TYPE_BEARER"
}

variable "id_token_role_assertion" {
  description = "Whether to include roles in ID token"
  type        = bool
  default     = true
}

variable "id_token_userinfo_assertion" {
  description = "Whether to include userinfo in ID token"
  type        = bool
  default     = true
}
