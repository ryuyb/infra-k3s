output "project_id" {
  description = "ZITADEL project ID"
  value       = zitadel_project.this.id
}

output "role_ids" {
  description = "Map of role IDs by role key"
  value       = { for k, v in zitadel_project_role.roles : k => v.id }
}

output "grant_ids" {
  description = "Map of grant IDs by grant key"
  value       = { for k, v in zitadel_user_grant.grants : k => v.id }
}
