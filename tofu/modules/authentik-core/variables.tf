variable "groups" {
  description = "Map of groups to create"
  type = map(object({
    is_superuser = optional(bool, false)
    attributes   = optional(map(string), {})
  }))
  default = {}
}
