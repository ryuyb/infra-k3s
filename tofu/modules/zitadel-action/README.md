# ZITADEL Action Module

This module manages ZITADEL custom actions and their triggers.

## Usage

```hcl
module "argocd_groups_claim_action" {
  source = "../../modules/zitadel-action"

  org_id = data.zitadel_org.default.id
  name   = "argocdGroupsClaim"
  script = file("${path.module}/scripts/argocd-groups-claim.js")

  trigger_pre_userinfo_creation      = true
  trigger_pre_access_token_creation  = true
}
```

## Inputs

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `org_id` | `string` | ZITADEL organization ID | - |
| `name` | `string` | Action name | - |
| `script` | `string` | Action script content | - |
| `timeout` | `string` | Action timeout | `"10s"` |
| `allowed_to_fail` | `bool` | Whether to allow action to fail | `true` |
| `flow_type` | `string` | Flow type for trigger actions | `"FLOW_TYPE_CUSTOMISE_TOKEN"` |
| `trigger_pre_userinfo_creation` | `bool` | Whether to trigger on pre userinfo creation | `true` |
| `trigger_pre_access_token_creation` | `bool` | Whether to trigger on pre access token creation | `true` |

## Outputs

| Name | Description |
|------|-------------|
| `action_id` | Action ID |
| `pre_userinfo_creation_trigger_id` | Pre userinfo creation trigger ID |
| `pre_access_token_creation_trigger_id` | Pre access token creation trigger ID |
