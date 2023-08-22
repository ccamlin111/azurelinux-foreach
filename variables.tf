//Basic variables.  Can be moved to a tfvars file if disired

variable "prefix" {
  default     = "K8S81823" //added date after name
  description = "The prefix which should be used for all resources in this module"
}

variable "location" {
  default     = "East US"
  description = "The Azure Region in which all resources in this example should be created."
}

variable "vm_map" {

  description = "A map of the various resources that require unique settings."
  type = map(object({
    name = string
  }))
  default = {
    "vm1" = {
      name = "vm1"
    }
    "vm2" = {
      name = "vm2"
    }
    "vm3" = {
      name = "vm3"
    }
    "controller" = {
      name = "controller"
    }
  }
}

