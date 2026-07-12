variable "subscription_id" {
  description = "Azure subscription ID. Leave null to use the active Azure CLI subscription."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Project name used in tags and resource naming."
  type        = string
  default     = "casopractico2"
}

variable "location" {
  description = "Azure region where resources will be created."
  type        = string
  default     = "swedencentral"
}

variable "environment" {
  description = "Environment tag and logical environment name."
  type        = string
  default     = "casopractico2"
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group."
  type        = string
  default     = "rg-casopractico2"
}

variable "admin_username" {
  description = "Admin username reserved for the Linux VM in later phases."
  type        = string
  default     = "azureuser"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to connect to SSH port 22. Use your public IP with /32 for a narrow rule."
  type        = string
}

variable "allowed_https_cidr" {
  description = "CIDR allowed to connect to HTTPS port 443."
  type        = string
  default     = "*"
}

variable "tags" {
  description = "Additional tags merged into all taggable resources."
  type        = map(string)
  default     = {}
}

variable "vnet_name" {
  description = "Name of the virtual network."
  type        = string
  default     = "vnet-cp2"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "vm_subnet_name" {
  description = "Name of the subnet reserved for the VM."
  type        = string
  default     = "snet-vm"
}

variable "vm_subnet_address_prefixes" {
  description = "Address prefixes for the VM subnet."
  type        = list(string)
  default     = ["10.20.1.0/24"]
}

variable "nsg_name" {
  description = "Name of the Network Security Group attached to the VM subnet."
  type        = string
  default     = "nsg-cp2-vm"
}

variable "acr_name" {
  description = "Globally unique Azure Container Registry name."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.acr_name))
    error_message = "acr_name must be globally unique, 5-50 characters long, and contain only letters and numbers."
  }
}

variable "vm_name" {
  description = "Name of the Linux virtual machine."
  type        = string
  default     = "vm-cp2"
}

variable "vm_size" {
  description = "Azure VM size for the Podman host."
  type        = string
  default     = "Standard_B2ats_v2"
}

variable "vm_public_ip_name" {
  description = "Name of the static public IP for the VM."
  type        = string
  default     = "pip-cp2-vm"
}

variable "vm_nic_name" {
  description = "Name of the network interface for the VM."
  type        = string
  default     = "nic-cp2-vm"
}

variable "ssh_public_key_path" {
  description = "Path to the local SSH public key used to access the VM."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Path to the local SSH private key used by Ansible to access the VM."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "aks_name" {
  description = "Name of the AKS cluster."
  type        = string
  default     = "aks-cp2"
}

variable "aks_dns_prefix" {
  description = "DNS prefix for the AKS cluster."
  type        = string
  default     = "akscp2"
}

variable "aks_node_count" {
  description = "Number of AKS worker nodes."
  type        = number
  default     = 1

  validation {
    condition     = var.aks_node_count == 1
    error_message = "aks_node_count must remain 1 for this practice."
  }
}

variable "aks_node_size" {
  description = "VM size for the AKS worker node."
  type        = string
  default     = "Standard_D2s_v3"
}
