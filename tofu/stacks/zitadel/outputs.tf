# ArgoCD Outputs
output "argocd_project_id" {
  description = "ArgoCD project ID"
  value       = module.argocd_project.project_id
}

output "argocd_application_id" {
  description = "ArgoCD OIDC application ID"
  value       = module.argocd_oidc.application_id
}

output "argocd_client_id" {
  description = "ArgoCD OIDC client ID"
  value       = module.argocd_oidc.client_id
  sensitive   = true
}

output "argocd_client_secret" {
  description = "ArgoCD OIDC client secret"
  value       = module.argocd_oidc.client_secret
  sensitive   = true
}

output "argocd_group_claim_action_id" {
  description = "ArgoCD groups claim action ID"
  value       = module.argocd_groups_claim_action.action_id
}

# OAuth2 Proxy Outputs
output "oauth2_proxy_project_id" {
  description = "OAuth2 Proxy project ID"
  value       = module.oauth2_proxy_project.project_id
}

output "oauth2_proxy_application_id" {
  description = "OAuth2 Proxy OIDC application ID"
  value       = module.oauth2_proxy_oidc.application_id
}

output "oauth2_proxy_client_id" {
  description = "OAuth2 Proxy OIDC client ID"
  value       = module.oauth2_proxy_oidc.client_id
  sensitive   = true
}

output "oauth2_proxy_client_secret" {
  description = "OAuth2 Proxy OIDC client secret"
  value       = module.oauth2_proxy_oidc.client_secret
  sensitive   = true
}
