terraform {
  required_providers {
    zitadel = {
      source  = "zitadel/zitadel"
      version = "2.7.0"
    }
  }
}

resource "zitadel_application_oidc" "this" {
  org_id     = var.org_id
  project_id = var.project_id

  name                      = var.name
  app_type                  = var.app_type
  response_types            = var.response_types
  grant_types               = var.grant_types
  auth_method_type          = var.auth_method_type
  redirect_uris             = var.redirect_uris
  post_logout_redirect_uris = var.post_logout_redirect_uris

  access_token_type           = var.access_token_type
  id_token_role_assertion     = var.id_token_role_assertion
  id_token_userinfo_assertion = var.id_token_userinfo_assertion
}
