# ZITADEL OIDC Application Module

This module manages ZITADEL OIDC applications.

## Usage

```hcl
module "argocd_oidc" {
  source = "../../modules/zitadel-oidc-app"

  name         = "argocd"
  org_id       = data.zitadel_org.default.id
  project_id   = module.argocd_project.project_id
  redirect_uris = ["${var.argocd_domain}/auth/callback"]
  post_logout_redirect_uris = [var.argocd_domain]
}
```

## Inputs

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `name` | `string` | OIDC application name | - |
| `org_id` | `string` | ZITADEL organization ID | - |
| `project_id` | `string` | ZITADEL project ID | - |
| `app_type` | `string` | OIDC application type | `"OIDC_APP_TYPE_WEB"` |
| `response_types` | `list(string)` | OIDC response types | `["OIDC_RESPONSE_TYPE_CODE"]` |
| `grant_types` | `list(string)` | OIDC grant types | `["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"]` |
| `auth_method_type` | `string` | OIDC authentication method type | `"OIDC_AUTH_METHOD_TYPE_BASIC"` |
| `redirect_uris` | `list(string)` | OIDC redirect URIs | - |
| `post_logout_redirect_uris` | `list(string)` | OIDC post logout redirect URIs | `[]` |
| `access_token_type` | `string` | OIDC access token type | `"OIDC_TOKEN_TYPE_BEARER"` |
| `id_token_role_assertion` | `bool` | Whether to include roles in ID token | `true` |
| `id_token_userinfo_assertion` | `bool` | Whether to include userinfo in ID token | `true` |

## Outputs

| Name | Description |
|------|-------------|
| `application_id` | OIDC application ID |
| `client_id` | OIDC client ID (sensitive) |
| `client_secret` | OIDC client secret (sensitive) |
