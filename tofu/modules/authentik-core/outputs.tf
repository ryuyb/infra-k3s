output "groups" {
  description = "Map of created groups"
  value = {
    for name, group in authentik_group.groups : name => {
      id   = group.id
      name = group.name
    }
  }
}
