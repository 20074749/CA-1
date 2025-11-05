variable "location" {
  description = "Azure region"
  type        = string
  default     = "francecentral"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "terraform-rg"
}

variable "vm_name" {
  description = "Virtual machine name"
  type        = string
  default     = "terraform-vm"
}

variable "vm_size" {
  description = "VM size"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "automation"
}


variable "ssh_public_key_path" {
  description = "Path to your SSH public key file"
  type        = string
  default     = "C:/Users/Rana Ahmad/.ssh/id_rsa.pub"
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}
