# subscription ids
variable "subscription_id" {
  type    = string
  default = "8817c809-4996-4b1c-a7c2-41e960bae57d"
}

# automation
variable "default_location" {
  type    = string
  default = "uksouth"
}

variable "rg" {
  type    = string
  default = "rg-cugc"
}

variable "nsg_cugc" {
  type    = string
  default = "nsg-cugc"
}

variable "vnet_cugc" {
  type    = string
  default = "vnet-cugc"
}

variable "st_automation_storage" {
  type    = string
  default = "stcugc"
}

variable "functionapp_cugc" {
  type    = string
  default = "fa-cugc"
}

variable "la_cugc" {
  type    = string
  default = "la-cugc"
}

variable "la_in_cugc" {
  type    = string
  default = "la-in-cugc"
}

variable "asp_cugc" {
  type    = string
  default = "asp-cugc"
}

variable "functionapp_provisioning_settings" {
  type = map(any)
  default = {
    PSWorkerInProcConcurrencyUpperBound = "40"
    FUNCTIONS_WORKER_PROCESS_COUNT      = "40"
  }
}

#bastion
variable "bastion_cugc" {
  type    = string
  default = "vnet-cugc-bastion"
}

variable "bastion_ip" {
  type    = string
  default = "vnet-cugc-ip"
}