terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

resource "cloudflare_record" "this" {
  for_each = var.records

  zone_id = var.zone_id
  name    = each.key
  type    = each.value.type
  content = each.value.value
  ttl     = lookup(each.value, "ttl", var.default_ttl)
  proxied = lookup(each.value, "proxied", var.default_proxied)
  comment = lookup(each.value, "comment", null)
}
