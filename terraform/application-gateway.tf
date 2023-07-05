locals {
  frontend_port_name             = "frontendport"
  frontend_ip_configuration_name = "agipconfig"
  backend_address_pool_name      = "backendpool"
  http_setting_name              = "httpsetting"
  listener_name                  = "listener"
  request_routing_rule_name      = "routingrule"
}

resource "azurerm_resource_group" "appgw" {
  for_each = toset(var.locations)

  name     = format("rg-appgw-%s-%s-%s", random_id.environment_id.hex, var.environment, each.value)
  location = each.value

  tags = var.tags
}

resource "azurerm_public_ip" "appgw" {
  for_each = toset(var.locations)

  name = format("pip%s%s%s", random_id.environment_id.hex, var.environment, each.value)

  resource_group_name = azurerm_resource_group.appgw[each.value].name
  location            = azurerm_resource_group.appgw[each.value].location

  allocation_method = "Static"
  sku               = "Standard"
}

resource "azurerm_application_gateway" "appgw" {
  for_each = toset(var.locations)

  name = format("appgw-%s-%s-%s", random_id.environment_id.hex, var.environment, each.value)

  resource_group_name = azurerm_resource_group.appgw[each.value].name
  location            = azurerm_resource_group.appgw[each.value].location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.frontend[each.value].id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.appgw[each.value].id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = 1
  }
}
