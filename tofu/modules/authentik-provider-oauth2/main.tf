terraform {
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
    }
  }
}

data "authentik_flow" "authorization" {
  slug = var.authorization_flow_slug
}

resource "authentik_provider_oauth2" "this" {
  name               = var.name
  client_id          = var.client_id
  client_secret      = var.client_secret
  authorization_flow = data.authentik_flow.authorization.id
  allowed_redirect_uris = var.redirect_uris
}

resource "authentik_application" "this" {
  name              = var.name
  slug              = var.slug
  protocol_provider = authentik_provider_oauth2.this.id
  group             = var.group
  meta_launch_url   = var.meta_launch_url
}
