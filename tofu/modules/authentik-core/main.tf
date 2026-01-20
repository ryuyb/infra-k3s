terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.0"
    }
  }
}

resource "authentik_group" "groups" {
  for_each = var.groups

  name         = each.key
  is_superuser = each.value.is_superuser
  attributes   = jsonencode(each.value.attributes)
}
