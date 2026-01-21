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

variable "argocd_external_host" {
  description = "External URL for Argo CD (e.g., https://argocd.example.com)"
  type        = string
}
