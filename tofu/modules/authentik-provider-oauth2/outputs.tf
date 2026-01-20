output "application_id" {
  value = authentik_application.this.uuid
}

output "provider_id" {
  value = authentik_provider_oauth2.this.id
}

output "client_id" {
  value = authentik_provider_oauth2.this.client_id
}

output "client_secret" {
  value     = authentik_provider_oauth2.this.client_secret
  sensitive = true
}
