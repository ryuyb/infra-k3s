output "application_id" {
  value = authentik_application.this.uuid
}

output "provider_id" {
  value = authentik_provider_ldap.this.id
}

output "base_dn" {
  value = authentik_provider_ldap.this.base_dn
}
