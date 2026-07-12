output "resource_group_name" {
  description = "Name of the Resource Group."
  value       = azurerm_resource_group.main.name
}

output "acr_name" {
  description = "Name of the Azure Container Registry."
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry."
  value       = azurerm_container_registry.main.login_server
}

output "acr_admin_username" {
  description = "Admin username for the Azure Container Registry."
  value       = azurerm_container_registry.main.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "Admin password for the Azure Container Registry."
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}

output "vnet_name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.main.name
}

output "subnet_id" {
  description = "ID of the VM subnet."
  value       = azurerm_subnet.vm.id
}

output "nsg_id" {
  description = "ID of the Network Security Group."
  value       = azurerm_network_security_group.vm.id
}

output "vm_public_ip" {
  description = "Public IP address of the Linux VM."
  value       = azurerm_public_ip.vm.ip_address
}

output "vm_private_ip" {
  description = "Private IP address of the Linux VM."
  value       = azurerm_network_interface.vm.private_ip_address
}

output "vm_admin_username" {
  description = "Admin username for SSH access to the Linux VM."
  value       = var.admin_username
}

output "ssh_connection_command" {
  description = "SSH command to connect to the Linux VM."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.vm.ip_address}"
}

output "aks_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_resource_group" {
  description = "Resource Group that contains the AKS cluster."
  value       = azurerm_resource_group.main.name
}

output "aks_get_credentials_command" {
  description = "Command to configure kubectl credentials for the AKS cluster."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
}

output "kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet identity used for AcrPull."
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
