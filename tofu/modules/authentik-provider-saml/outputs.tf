output "application_id" {
  value = authentik_application.this.uuid
}

output "provider_id" {
  value = authentik_provider_saml.this.id
}

output "metadata_url" {
  value = "authentik://providers/saml/${authentik_provider_saml.this.id}/metadata/"
}
