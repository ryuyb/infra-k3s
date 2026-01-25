output "application_id" {
  description = "OIDC application ID"
  value       = zitadel_application_oidc.this.id
}

output "client_id" {
  description = "OIDC client ID"
  value       = zitadel_application_oidc.this.client_id
  sensitive   = true
}

output "client_secret" {
  description = "OIDC client secret"
  value       = zitadel_application_oidc.this.client_secret
  sensitive   = true
}
