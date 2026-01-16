output "records" {
  description = "Created DNS records"
  value = {
    for k, v in cloudflare_record.this : k => {
      id      = v.id
      name    = v.name
      type    = v.type
      content = v.content
      proxied = v.proxied
    }
  }
}
