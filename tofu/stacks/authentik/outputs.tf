output "kubewall_application_id" {
  description = "Kubewall application UUID"
  value       = module.kubewall_proxy.application_id
}

output "kubewall_provider_id" {
  description = "Kubewall proxy provider ID"
  value       = module.kubewall_proxy.provider_id
}
