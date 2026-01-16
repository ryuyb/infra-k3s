# Cloudflare
variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

# Domain
variable "domain" {
  description = "Primary domain name"
  type        = string
}

# Cluster
variable "cluster_ingress_ip" {
  description = "K3s cluster ingress IP (Traefik LoadBalancer)"
  type        = string
}
