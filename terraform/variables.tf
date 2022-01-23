variable "cloudflare_id" {
  type = map
  default = {
    "email" = ""
    "api_key" = ""
    "zone_id" = ""
    "dns_name" = ""
  }
}

variable "scaleway_id" {
  type = map
  default = {
  "zone"            = ""
  "region"          = ""
  "access_key" = ""
  "secret_key" = ""
  "project_id" = ""
}
  }

variable "kube_size" {
  type = number
  default = 2
}

variable "bucket_id" {
  type = map
  default = {
  "id"            = ""
  "key"          = ""
}
  }


variable "mysql_id" {
  type = map
  default = {
  "username"          = "minecraft"
  "password"          = "Epsi2021!"
}
  }
