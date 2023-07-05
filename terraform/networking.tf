resource "azurerm_resource_group" "vnet" {
  for_each = toset(var.locations)

  name     = format("rg-vnet-%s-%s-%s", random_id.environment_id.hex, var.environment, each.value)
  location = each.value

  tags = var.tags
}

resource "azurerm_virtual_network" "apps" {
  for_each = toset(var.locations)

  name          = format("vnet-%s-%s-%s", random_id.environment_id.hex, var.environment, each.value)
  address_space = [var.address_spaces[each.value]]

  resource_group_name = azurerm_resource_group.vnet[each.value].name
  location            = azurerm_resource_group.vnet[each.value].location
}

resource "azurerm_subnet" "endpoints" {
  for_each = toset(var.locations)

  name = format("snet-integration-%s-%s-%s", random_id.environment_id.hex, var.environment, each.value)

  resource_group_name  = azurerm_resource_group.vnet[each.value].name
  virtual_network_name = azurerm_virtual_network.apps[each.value].name

  address_prefixes = [var.subnets[each.value]["endpoints"]]
}

resource "azurerm_subnet" "frontend" {
  for_each = toset(var.locations)

  name = format("snet-frontend-01-%s-%s-%s", random_id.environment_id.hex, var.environment, each.value)

  resource_group_name  = azurerm_resource_group.vnet[each.value].name
  virtual_network_name = azurerm_virtual_network.apps[each.value].name

  address_prefixes = [var.subnets[each.value]["frontend"]]
}

resource "azurerm_subnet" "backend" {
  for_each = toset(var.locations)

  name = format("snet-backend-02-%s-%s-%s", random_id.environment_id.hex, var.environment, each.value)

  resource_group_name  = azurerm_resource_group.vnet[each.value].name
  virtual_network_name = azurerm_virtual_network.apps[each.value].name

  address_prefixes = [var.subnets[each.value]["backend"]]
}
