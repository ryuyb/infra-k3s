terraform {
  required_version = ">= 1.6.0"

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

# ============================================================================
# Data Sources
# ============================================================================

data "zitadel_org" "default" {
  id = var.zitadel_default_org_id
}

data "zitadel_human_user" "default" {
  org_id  = data.zitadel_org.default.id
  user_id = var.zitadel_default_user_id
}

# ============================================================================
# ArgoCD Project & OIDC Configuration
# ============================================================================

module "argocd_project" {
  source = "../../modules/zitadel-project"

  name                   = "argocd"
  org_id                 = data.zitadel_org.default.id
  project_role_assertion = true
  project_role_check     = true

  roles = {
    argocd_administrators = {
      display_name = "ArgoCD Administrators"
    }
    argocd_users = {
      display_name = "ArgoCD Users"
    }
  }

  grants = {
    admin_default = {
      user_id   = data.zitadel_human_user.default.id
      role_keys = ["argocd_administrators"]
    }
  }
}

module "argocd_oidc" {
  source = "../../modules/zitadel-oidc-app"

  name         = "argocd"
  org_id       = data.zitadel_org.default.id
  project_id   = module.argocd_project.project_id
  redirect_uris = ["${var.argocd_domain}/auth/callback"]
  post_logout_redirect_uris = [var.argocd_domain]
}

# ============================================================================
# Custom Action: Groups Claim
# ============================================================================

module "argocd_groups_claim_action" {
  source = "../../modules/zitadel-action"

  org_id = data.zitadel_org.default.id
  name   = "argocdGroupsClaim"
  script = file("${path.module}/scripts/argocd-groups-claim.js")

  trigger_pre_userinfo_creation      = true
  trigger_pre_access_token_creation  = true
}

# ============================================================================
# OAuth2 Proxy Project & OIDC Configuration
# ============================================================================

module "oauth2_proxy_project" {
  source = "../../modules/zitadel-project"

  name                   = "oauth2-proxy"
  org_id                 = data.zitadel_org.default.id
  project_role_assertion = false
  project_role_check     = false
}

module "oauth2_proxy_oidc" {
  source = "../../modules/zitadel-oidc-app"

  name         = "oauth2-proxy"
  org_id       = data.zitadel_org.default.id
  project_id   = module.oauth2_proxy_project.project_id
  redirect_uris = ["${var.oauth2_proxy_domain}/oauth2/callback"]
}

# ============================================================================
# Apps Project
# ============================================================================

module "apps_project" {
  source = "../../modules/zitadel-project"

  name                   = "apps"
  org_id                 = data.zitadel_org.default.id
  project_role_assertion = false
  project_role_check     = false
}

# ============================================================================
# VaultWarden
# ============================================================================

module "vaultwarden_oidc" {
  source = "../../modules/zitadel-oidc-app"

  name         = "Vaultwarden"
  org_id       = data.zitadel_org.default.id
  project_id   = module.apps_project.project_id
  grant_types  = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE", "OIDC_GRANT_TYPE_REFRESH_TOKEN"]
  redirect_uris = ["${var.vaultwarden_domain}/identity/connect/oidc-signin"]
}
