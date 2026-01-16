# DNS Records
module "dns" {
  source  = "../../modules/cloudflare-dns"
  zone_id = var.cloudflare_zone_id

  records = {
    # Wildcard record for all services
    "*" = {
      type    = "A"
      value   = var.cluster_ingress_ip
      proxied = true
      comment = "K3s cluster wildcard"
    }

    # Root domain
    "@" = {
      type    = "A"
      value   = var.cluster_ingress_ip
      proxied = true
      comment = "K3s cluster root"
    }

    # Specific services (optional, for non-proxied or different IPs)
    # "api" = {
    #   type    = "A"
    #   value   = var.cluster_ingress_ip
    #   proxied = false
    #   comment = "K3s API (direct)"
    # }
  }
}
