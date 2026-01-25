terraform {
  required_providers {
    zitadel = {
      source  = "zitadel/zitadel"
      version = "2.7.0"
    }
  }
}

resource "zitadel_project" "this" {
  name                   = var.name
  org_id                 = var.org_id
  project_role_assertion = var.project_role_assertion
  project_role_check     = var.project_role_check
}

resource "zitadel_project_role" "roles" {
  for_each = var.roles

  org_id       = var.org_id
  project_id   = zitadel_project.this.id
  role_key     = each.key
  display_name = each.value.display_name
}

resource "zitadel_user_grant" "grants" {
  for_each = var.grants

  org_id     = var.org_id
  project_id = zitadel_project.this.id
  user_id    = each.value.user_id
  role_keys  = each.value.role_keys
}
