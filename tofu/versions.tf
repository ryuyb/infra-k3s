terraform {
  required_version = ">= 1.6.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.0"
    }
  }
}
