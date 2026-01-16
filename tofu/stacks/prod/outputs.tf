output "dns_records" {
  description = "Created DNS records"
  value       = module.dns.records
}

output "velero_bucket" {
  description = "Velero backup bucket name"
  value       = module.velero_bucket.bucket_name
}
