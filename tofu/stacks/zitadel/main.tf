terraform {
  required_providers {
    zitadel = {
      source  = "zitadel/zitadel"
      version = "2.7.0"
    }
  }
}

provider "zitadel" {
  domain       = var.zitadel_domain
  access_token = var.zitadel_access_token
}

data "zitadel_org" "default" {
  id = var.zitadel_default_org_id
}

data "zitadel_human_user" "default" {
  org_id  = data.zitadel_org.default.id
  user_id = var.zitadel_default_user_id
}

resource "zitadel_project" "argocd" {
  name                   = "argocd"
  org_id                 = data.zitadel_org.default.id
  project_role_assertion = true
  project_role_check     = true
}

resource "zitadel_project_role" "argocd_administrators" {
  org_id       = data.zitadel_org.default.id
  project_id   = zitadel_project.argocd.id
  role_key     = "argocd_administrators"
  display_name = "ArgoCD Administrators"
}

resource "zitadel_project_role" "argocd_users" {
  org_id       = data.zitadel_org.default.id
  project_id   = zitadel_project.argocd.id
  role_key     = "argocd_users"
  display_name = "ArgoCD Users"
}

resource "zitadel_user_grant" "argocd_admin_default_user" {
  org_id     = data.zitadel_org.default.id
  project_id = zitadel_project.argocd.id
  user_id    = data.zitadel_human_user.default.id
  role_keys  = [zitadel_project_role.argocd_administrators.role_key]
}

resource "zitadel_application_oidc" "argocd_app" {
  org_id     = data.zitadel_org.default.id
  project_id = zitadel_project.argocd.id

  name                      = "argocd"
  app_type                  = "OIDC_APP_TYPE_WEB"
  response_types            = ["OIDC_RESPONSE_TYPE_CODE"]
  grant_types               = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"]
  auth_method_type          = "OIDC_AUTH_METHOD_TYPE_BASIC"
  redirect_uris             = ["${var.argocd_domain}/auth/callback"]
  post_logout_redirect_uris = [var.argocd_domain]

  access_token_type           = "OIDC_TOKEN_TYPE_BEARER"
  id_token_role_assertion     = true
  id_token_userinfo_assertion = true
}

resource "zitadel_action" "argocd_groups_claim" {
  org_id          = data.zitadel_org.default.id
  name            = "argocdGroupsClaim"
  script          = <<-EOF
/**
 * sets the roles an additional claim in the token with roles as value an project as key
 *
 * The role claims of the token look like the following:
 *
 * // added by the code below
 * "groups": ["{roleName}", "{roleName}", ...],
 *
 * Flow: Complement token, Triggers: Pre Userinfo creation, Pre access token creation
 *
 * @param ctx
 * @param api
 */
function argocdGroupsClaim(ctx, api) {
  if (ctx.v1.user.grants === undefined || ctx.v1.user.grants.count == 0) {
    return;
  }

  let grants = [];
  ctx.v1.user.grants.grants.forEach((claim) => {
    claim.roles.forEach((role) => {
      grants.push(role);
    });
  });

  api.v1.claims.setClaim("groups", grants);
}
EOF
  timeout         = "10s"
  allowed_to_fail = true
}

resource "zitadel_trigger_actions" "argocd_pre_userinfo_creation" {
  org_id       = data.zitadel_org.default.id
  flow_type    = "FLOW_TYPE_CUSTOMISE_TOKEN"
  trigger_type = "TRIGGER_TYPE_PRE_USERINFO_CREATION"
  action_ids   = [zitadel_action.argocd_groups_claim.id]
}

resource "zitadel_trigger_actions" "argocd_pre_access_token_creation" {
  org_id       = data.zitadel_org.default.id
  flow_type    = "FLOW_TYPE_CUSTOMISE_TOKEN"
  trigger_type = "TRIGGER_TYPE_PRE_ACCESS_TOKEN_CREATION"
  action_ids   = [zitadel_action.argocd_groups_claim.id]
}
