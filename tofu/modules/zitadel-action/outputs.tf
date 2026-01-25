output "action_id" {
  description = "Action ID"
  value       = zitadel_action.this.id
}

output "pre_userinfo_creation_trigger_id" {
  description = "Pre userinfo creation trigger ID"
  value       = try(zitadel_trigger_actions.pre_userinfo_creation["enabled"].id, null)
}

output "pre_access_token_creation_trigger_id" {
  description = "Pre access token creation trigger ID"
  value       = try(zitadel_trigger_actions.pre_access_token_creation["enabled"].id, null)
}
