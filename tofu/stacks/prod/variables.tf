variable "authentik_url" {
  description = "Authentik API URL"
  type        = string
}

variable "authentik_token" {
  description = "Authentik API token"
  type        = string
  sensitive   = true
}

variable "kubewall_external_host" {
  description = "External URL for Kubewall (e.g., https://kubewall.example.com)"
  type        = string
}

variable "kubewall_internal_host" {
  description = "Internal URL for Kubewall (e.g., http://kubewall.apps.svc.cluster.local:8080)"
  type        = string
}
