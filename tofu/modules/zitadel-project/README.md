# ZITADEL Project Module

This module manages ZITADEL projects, including project roles and user grants.

## Usage

```hcl
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
```

## Inputs

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `name` | `string` | Project name | - |
| `org_id` | `string` | ZITADEL organization ID | - |
| `project_role_assertion` | `bool` | Whether to assert roles in the token | `false` |
| `project_role_check` | `bool` | Whether to check roles | `false` |
| `roles` | `map(object)` | Map of project roles | `{}` |
| `grants` | `map(object)` | Map of user grants | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `project_id` | ZITADEL project ID |
| `role_ids` | Map of role IDs by role key |
| `grant_ids` | Map of grant IDs by grant key |
