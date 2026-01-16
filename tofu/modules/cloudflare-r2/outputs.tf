output "bucket_name" {
  description = "R2 bucket name"
  value       = cloudflare_r2_bucket.this.name
}

output "bucket_id" {
  description = "R2 bucket ID"
  value       = cloudflare_r2_bucket.this.id
}
