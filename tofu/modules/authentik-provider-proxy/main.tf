terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.0"
    }
  }
}

data "authentik_flow" "authorization" {
  slug = var.authorization_flow_slug
}

data "authentik_flow" "invalidation" {
  slug = var.invalidation_flow_slug
}

resource "authentik_provider_proxy" "this" {
  name               = var.name
  external_host      = var.external_host
  internal_host      = var.internal_host != "" ? var.internal_host : null
  authorization_flow = data.authentik_flow.authorization.id
  invalidation_flow  = data.authentik_flow.invalidation.id
  mode               = var.mode
}

resource "authentik_application" "this" {
  name              = var.name
  slug              = var.slug
  protocol_provider = authentik_provider_proxy.this.id
  group             = var.group
  meta_launch_url   = var.meta_launch_url != "" ? var.meta_launch_url : var.external_host
  open_in_new_tab   = var.open_in_new_tab
}
