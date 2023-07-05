@description('Location for all resources.')
param location string = resourceGroup().location

var virtualNetworks_myVNet_name = 'myVNet'
var publicIPAddress_name = 'public_ip'
var applicationGateways_myAppGateway_name = 'myAppGateway'
var vnet_prefix = '10.0.0.0/16'
var ag_subnet_prefix = '10.0.1.0/24'
var backend_subnet_prefix = '10.0.2.0/24'
var endpoint_subnets_prefix = '10.0.3.0/24'

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2021-08-01' = [for i in range(0, 3): {
  name: '${publicIPAddress_name}${i}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}]

resource myVNet 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: virtualNetworks_myVNet_name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet_prefix
      ]
    }
    subnets: [
      {
        name: 'endpointsSubnet'
        properties: {
          addressPrefix: endpoint_subnets_prefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'myAGSubnet'
        properties: {
          addressPrefix: ag_subnet_prefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'myBackendSubnet'
        properties: {
          addressPrefix: backend_subnet_prefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource myAppGateway 'Microsoft.Network/applicationGateways@2021-08-01' = {
  name: applicationGateways_myAppGateway_name
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworks_myVNet_name, 'myAGSubnet')
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', '${publicIPAddress_name}0')
          }
        }
      }
      {
        name: 'private'
        properties: {
          privateIPAddress: '10.0.1.10'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworks_myVNet_name, 'myAGSubnet')
          }
          privateLinkConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/privateLinkConfigurations', applicationGateways_myAppGateway_name, 'private')
          }
        }
      }
    ]
    privateLinkConfigurations: [
      {
        name: 'private'
        properties: {
          ipConfigurations: [
            {
              name: 'private'
              properties: {
                privateIPAllocationMethod: 'Dynamic'
                primary: true
                subnet: {
                  id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworks_myVNet_name, 'endpointsSubnet')
                }
              }
            }
          ]
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'myBackendPool'
        properties: {}
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'myHTTPSetting'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'myListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGateways_myAppGateway_name, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGateways_myAppGateway_name, 'port_80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'myRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 10
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGateways_myAppGateway_name, 'myListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGateways_myAppGateway_name, 'myBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGateways_myAppGateway_name, 'myHTTPSetting')
          }
        }
      }
    ]
    enableHttp2: false
  }
  dependsOn: [
    myVNet
    publicIPAddress
  ]
}
