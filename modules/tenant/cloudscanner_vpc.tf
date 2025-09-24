locals {
  network_address_space = "10.0.0.0/16"
  subnet_ip_cidr_range  = "10.0.0.0/21"

  create_vnet = local.cloudscanner_enabled && var.key_vault_deny_traffic # Futureproofing: We may want to create a VNet even if we don't have key vault deny traffic
}

resource "azurerm_virtual_network" "cloudscanner_network" {
  count               = local.create_vnet ? 1 : 0
  name                = "upwind-cs-network-${var.upwind_organization_id}"
  resource_group_name = azurerm_resource_group.orgwide_resource_group[0].name
  location            = var.azure_cloudscanner_location
  address_space       = [local.network_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "cloudscanner_subnet" {
  count                = local.create_vnet ? 1 : 0
  name                 = "upwind-cs-subnet-${var.upwind_organization_id}"
  resource_group_name  = azurerm_resource_group.orgwide_resource_group[0].name
  virtual_network_name = azurerm_virtual_network.cloudscanner_network[0].name
  address_prefixes     = [local.subnet_ip_cidr_range]
  service_endpoints    = ["Microsoft.KeyVault"]
}

resource "azurerm_network_security_group" "clouscanner_sg" {
  count               = local.create_vnet ? 1 : 0
  name                = "upwind-cs-sg-${var.upwind_organization_id}"
  resource_group_name = azurerm_resource_group.orgwide_resource_group[0].name
  location            = var.azure_cloudscanner_location
  tags                = var.tags

  # Allow outbound traffic
  security_rule {
    name                       = "AllowOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "cloudscanner_subnet_nsg_association" {
  count                     = local.create_vnet ? 1 : 0
  subnet_id                 = azurerm_subnet.cloudscanner_subnet[0].id
  network_security_group_id = azurerm_network_security_group.clouscanner_sg[0].id
}
