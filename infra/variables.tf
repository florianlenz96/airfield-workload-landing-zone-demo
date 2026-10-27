# Everything about the landing zone arrives in one variable. The pipeline sets it from
# the GitHub variable LANDING_ZONE, which the platform wrote into this repository.
variable "landing_zone" {
  type = object({
    name                 = string
    subscription_id      = string
    location             = string
    tags                 = map(string)
    vnet_id              = string
    subnet_ids           = map(string)
    private_dns_zone_ids = map(string)
  })
}

variable "app_name" {
  type    = string
  default = "meter-readings"
}
