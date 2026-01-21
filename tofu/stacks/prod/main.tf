terraform {
  required_version = ">= 1.6.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.0"
    }
  }
}

# Configure Authentik provider
provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_token
}

# Kubewall Proxy Provider
module "kubewall_proxy" {
  source = "../../modules/authentik-provider-proxy"

  name          = "Kubewall"
  slug          = "kubewall"
  external_host = var.kubewall_external_host
  mode          = "forward_single"
  group         = "Infrastructure"

  # Use default authorization and invalidation flows
  authorization_flow_slug = "default-provider-authorization-implicit-consent"
  invalidation_flow_slug  = "default-provider-invalidation-flow"
}

# Argocd Proxy Provider
module "argocd_proxy" {
  source = "../../modules/authentik-provider-proxy"

  name          = "Argo CD"
  slug          = "argocd"
  external_host = var.argocd_external_host
  mode          = "forward_single"
  group         = "Infrastructure"

  # Use default authorization and invalidation flows
  authorization_flow_slug = "default-provider-authorization-implicit-consent"
  invalidation_flow_slug  = "default-provider-invalidation-flow"
}
