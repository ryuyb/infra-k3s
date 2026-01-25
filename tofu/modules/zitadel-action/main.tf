terraform {
  required_providers {
    zitadel = {
      source  = "zitadel/zitadel"
      version = "2.7.0"
    }
  }
}

resource "zitadel_action" "this" {
  org_id          = var.org_id
  name            = var.name
  script          = var.script
  timeout         = var.timeout
  allowed_to_fail = var.allowed_to_fail
}

resource "zitadel_trigger_actions" "pre_userinfo_creation" {
  for_each = var.trigger_pre_userinfo_creation ? { "enabled" = true } : {}

  org_id       = var.org_id
  flow_type    = var.flow_type
  trigger_type = "TRIGGER_TYPE_PRE_USERINFO_CREATION"
  action_ids   = [zitadel_action.this.id]
}

resource "zitadel_trigger_actions" "pre_access_token_creation" {
  for_each = var.trigger_pre_access_token_creation ? { "enabled" = true } : {}

  org_id       = var.org_id
  flow_type    = var.flow_type
  trigger_type = "TRIGGER_TYPE_PRE_ACCESS_TOKEN_CREATION"
  action_ids   = [zitadel_action.this.id]
}
