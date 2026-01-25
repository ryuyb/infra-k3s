variable "org_id" {
  description = "ZITADEL organization ID"
  type        = string
}

variable "name" {
  description = "Action name"
  type        = string
}

variable "script" {
  description = "Action script content"
  type        = string
}

variable "timeout" {
  description = "Action timeout"
  type        = string
  default     = "10s"
}

variable "allowed_to_fail" {
  description = "Whether to allow action to fail"
  type        = bool
  default     = true
}

variable "flow_type" {
  description = "Flow type for trigger actions"
  type        = string
  default     = "FLOW_TYPE_CUSTOMISE_TOKEN"
}

variable "trigger_pre_userinfo_creation" {
  description = "Whether to trigger on pre userinfo creation"
  type        = bool
  default     = true
}

variable "trigger_pre_access_token_creation" {
  description = "Whether to trigger on pre access token creation"
  type        = bool
  default     = true
}
