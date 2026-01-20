terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.0"
    }
  }
}

data "authentik_flow" "bind" {
  slug = var.bind_flow_slug
}

resource "authentik_provider_ldap" "this" {
  name         = var.name
  base_dn      = var.base_dn
  bind_flow    = data.authentik_flow.bind.id
  search_group = var.search_group
}

resource "authentik_application" "this" {
  name              = var.name
  slug              = var.slug
  protocol_provider = authentik_provider_ldap.this.id
  group             = var.group
}
