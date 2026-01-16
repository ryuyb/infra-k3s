# R2 Buckets
module "velero_bucket" {
  source      = "../../modules/cloudflare-r2"
  account_id  = var.cloudflare_account_id
  bucket_name = "k3s-velero-backups"
  location    = "apac"
}

# Additional buckets can be added here
# module "app_storage" {
#   source      = "../../modules/cloudflare-r2"
#   account_id  = var.cloudflare_account_id
#   bucket_name = "k3s-app-storage"
# }
