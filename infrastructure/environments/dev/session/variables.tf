variable "env" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "swedencentral"
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.10.0.0/16"]
}

variable "nodes_subnet_prefix" {
  type    = string
  default = "10.10.0.0/24"
}
