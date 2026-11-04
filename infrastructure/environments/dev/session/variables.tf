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

variable "pod_cidr" {
  type    = string
  default = "10.244.0.0/16"
}

variable "service_cidr" {
  type    = string
  default = "10.96.0.0/16"
}

variable "dns_service_ip" {
  type    = string
  default = "10.96.0.10"
}

variable "kubernetes_version" {
  type    = string
  default = "1.36.5"
}

variable "node_vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "api_authorized_ip_ranges" {
  type        = list(string)
  description = "CIDR ranges allowed to reach the Kubernetes API. Set at run time. No default."

  validation {
    condition = (
      length(var.api_authorized_ip_ranges) > 0 &&
      !contains(var.api_authorized_ip_ranges, "0.0.0.0/0") &&
      alltrue([for r in var.api_authorized_ip_ranges : can(cidrhost(r, 0))])
    )
    error_message = "Give at least one valid CIDR range. 0.0.0.0/0 is not allowed."
  }
}
