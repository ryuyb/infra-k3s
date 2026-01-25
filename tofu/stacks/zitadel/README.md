# ZITADEL Stack

This stack manages ZITADEL configuration for ArgoCD and OAuth2 Proxy OIDC authentication.

## Structure

```
tofu/stacks/zitadel/
├── main.tf                    # Main configuration using modules
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output definitions
├── terraform.tfvars           # Actual variable values (gitignored)
├── terraform.tfvars.example   # Example configuration
└── scripts/
    └── argocd-groups-claim.js # Custom action script

tofu/modules/
├── zitadel-project/           # Manages ZITADEL projects and roles
├── zitadel-oidc-app/          # Manages ZITADEL OIDC applications
└── zitadel-action/            # Manages ZITADEL custom actions
```

## Modules

### zitadel-project
Manages ZITADEL projects, including:
- Project creation
- Project roles
- User grants

### zitadel-oidc-app
Manages ZITADEL OIDC applications, including:
- OIDC application configuration
- Redirect URIs
- Post logout redirect URIs
- Token settings

### zitadel-action
Manages ZITADEL custom actions, including:
- Action script execution
- Trigger configurations (pre userinfo creation, pre access token creation)

## Configuration

### ArgoCD
- **Project**: `argocd`
- **Roles**: `argocd_administrators`, `argocd_users`
- **OIDC Application**: `argocd`
- **Redirect URI**: `${argocd_domain}/auth/callback`
- **Post Logout Redirect URI**: `${argocd_domain}`
- **Custom Action**: `argocdGroupsClaim` - adds groups claim to tokens

### OAuth2 Proxy
- **Project**: `oauth2-proxy`
- **OIDC Application**: `oauth2-proxy`
- **Redirect URI**: `${oauth2_proxy_domain}/oauth2/callback`

## Usage

### 1. Configure Variables

Create `terraform.tfvars` with your values:

```hcl
zitadel_domain          = "https://zitadel.your-domain.com"
zitadel_access_token    = "your-access-token"
zitadel_default_org_id  = "your-org-id"
zitadel_default_user_id = "your-user-id"
argocd_domain           = "https://argocd.your-domain.com"
oauth2_proxy_domain     = "https://oauth2-proxy.your-domain.com"
```

Or copy and edit the example:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Initialize and Apply

```bash
cd tofu/stacks/zitadel

# Initialize
tofu init

# Plan
tofu plan

# Apply
tofu apply
```

### 3. Use Outputs

After applying, you can use the outputs to configure ArgoCD:

```bash
# Get ArgoCD client ID and secret
tofu output argocd_client_id
tofu output argocd_client_secret

# Get OAuth2 Proxy client ID and secret
tofu output oauth2_proxy_client_id
tofu output oauth2_proxy_client_secret
```

## Outputs

### ArgoCD
- `argocd_project_id` - ArgoCD project ID
- `argocd_application_id` - ArgoCD OIDC application ID
- `argocd_client_id` - ArgoCD OIDC client ID (sensitive)
- `argocd_client_secret` - ArgoCD OIDC client secret (sensitive)
- `argocd_group_claim_action_id` - ArgoCD groups claim action ID

### OAuth2 Proxy
- `oauth2_proxy_project_id` - OAuth2 Proxy project ID
- `oauth2_proxy_application_id` - OAuth2 Proxy OIDC application ID
- `oauth2_proxy_client_id` - OAuth2 Proxy OIDC client ID (sensitive)
- `oauth2_proxy_client_secret` - OAuth2 Proxy OIDC client secret (sensitive)

## Custom Action: Groups Claim

The `argocd-groups-claim.js` script adds a `groups` claim to OIDC tokens containing all roles from user grants. This is used by ArgoCD for RBAC group mapping.

Example token claim:
```json
{
  "groups": ["argocd_administrators", "argocd_users"]
}
```

## Adding New Applications

To add a new OIDC application:

1. **Add to main.tf**:
   ```hcl
   module "new_app_project" {
     source = "../../modules/zitadel-project"
     name   = "new-app"
     org_id = data.zitadel_org.default.id
     # ... other configuration
   }

   module "new_app_oidc" {
     source = "../../modules/zitadel-oidc-app"
     name   = "new-app"
     org_id = data.zitadel_org.default.id
     project_id = module.new_app_project.project_id
     redirect_uris = ["https://new-app.example.com/callback"]
   }
   ```

2. **Add outputs** to `outputs.tf`:
   ```hcl
   output "new_app_client_id" {
     description = "New App OIDC client ID"
     value       = module.new_app_oidc.client_id
     sensitive   = true
   }
   ```

3. **Apply changes**:
   ```bash
   tofu apply
   ```

## Benefits of Module Structure

1. **Reusability**: Modules can be reused across different projects
2. **Maintainability**: Each module has a single responsibility
3. **Testability**: Modules can be tested independently
4. **Documentation**: Each module has its own README
5. **Flexibility**: Easy to add new applications or modify existing ones
6. **Organization**: Clear separation of concerns

## Migration from Single File

The original `main.tf` had all resources defined in a single file. The new structure:

- **Before**: All resources in one file, hard-coded names, no outputs
- **After**: Modular structure with reusable components, proper outputs, and better organization

This makes it easier to:
- Add new ZITADEL resources
- Maintain existing configuration
- Understand the infrastructure
- Collaborate with team members
