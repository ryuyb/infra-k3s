output "application_id" {
  value = authentik_application.this.uuid
}

output "provider_id" {
  value = authentik_provider_proxy.this.id
}
