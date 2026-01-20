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

resource "authentik_provider_saml" "this" {
  name               = var.name
  authorization_flow = data.authentik_flow.authorization.id
  acs_url            = var.acs_url
  issuer             = var.issuer
  audience           = var.audience
}

resource "authentik_application" "this" {
  name              = var.name
  slug              = var.slug
  protocol_provider = authentik_provider_saml.this.id
  group             = var.group
  meta_launch_url   = var.meta_launch_url
}
