@description('The location of the resources deployed. Default to same as resource group')
param location string
param commonResourceTags object
@description('The name of the vnet')
param name string
param routeTableName string

var storageSuffixByEnv = environment().suffixes.storage

resource vNet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: name
  location: location
  tags: commonResourceTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.0.0/26'
        }
      }
      {
        name: 'jumpbox'
        properties: {
          addressPrefix: '10.0.0.64/29'
          routeTable: {
            id: resourceId('Microsoft.Network/routeTables', routeTable.name)
          }
        }
      }
      {
        name: 'serverFarms'
        properties: {
          addressPrefix: '10.0.0.72/29'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'aks'
        properties: {
          addressPrefix: '10.0.1.0/24'
          routeTable: {
            id: resourceId('Microsoft.Network/routeTables', routeTable.name)
          }
        }
      }
      {
        name: 'endpoints'
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.3.0/26'
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: '10.0.3.64/26'
        }
      }
      {
        name: 'AppGatewaySubnet'
        properties: {
          addressPrefix: '10.0.5.0/26'
        }
      }
    ]
  }
}

resource routeTable 'Microsoft.Network/routeTables@2022-05-01' = {
  name: routeTableName
  location: location
  tags: commonResourceTags
}

resource privateDnsZoneBlob 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${storageSuffixByEnv}'
  location: 'global'
  tags: commonResourceTags

  resource zoneVnetLink 'virtualNetworkLinks' = {
    name: '${privateDnsZoneBlob.name}-link'
    location: 'global'
    tags: commonResourceTags
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vNet.id
      }
    }
  }
}

resource privateDnsZoneDfs 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.dfs.${storageSuffixByEnv}'
  location: 'global'
  tags: commonResourceTags

  resource zoneVnetLink 'virtualNetworkLinks' = {
    name: '${privateDnsZoneDfs.name}-link'
    location: 'global'
    tags: commonResourceTags
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vNet.id
      }
    }
  }
}

resource privateDnsZoneQueue 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.queue.${storageSuffixByEnv}'
  location: 'global'
  tags: commonResourceTags

  resource zoneVnetLink 'virtualNetworkLinks' = {
    name: '${privateDnsZoneQueue.name}-link'
    location: 'global'
    tags: commonResourceTags
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vNet.id
      }
    }
  }
}

resource privateDnsZoneFile 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.${storageSuffixByEnv}'
  location: 'global'
  tags: commonResourceTags

  resource zoneVnetLink 'virtualNetworkLinks' = {
    name: '${privateDnsZoneFile.name}-link'
    location: 'global'
    tags: commonResourceTags
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vNet.id
      }
    }
  }
}

resource privateDnsZoneTable 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.table.${storageSuffixByEnv}'
  location: 'global'
  tags: commonResourceTags

  resource zoneVnetLink 'virtualNetworkLinks' = {
    name: '${privateDnsZoneFile.name}-link'
    location: 'global'
    tags: commonResourceTags
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vNet.id
      }
    }
  }
}

resource privateDnsZoneKv 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: commonResourceTags

  resource zoneVnetLink 'virtualNetworkLinks' = {
    name: '${privateDnsZoneKv.name}-link'
    location: 'global'
    tags: commonResourceTags
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vNet.id
      }
    }
  }
}

resource privateDnsZoneSqlSynapase 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.sql.azuresynapse.net'
  location: 'global'
  tags: commonResourceTags

  resource zoneVnetLink 'virtualNetworkLinks' = {
    name: '${privateDnsZoneSqlSynapase.name}-link'
    location: 'global'
    tags: commonResourceTags
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vNet.id
      }
    }
  }
}

output vnetId string = vNet.id
output firewallSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vNet.name, 'AzureFirewallSubnet')
output jumpboxSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vNet.name, 'jumpbox')
output aksSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vNet.name, 'aks')
output endpointsSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vNet.name, 'endpoints')
output serverFarmsSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vNet.name, 'serverFarms')
output bastionSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vNet.name, 'AzureBastionSubnet')
output agwSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vNet.name, 'AppGatewaySubnet')
output firewallManagementSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vNet.name, 'AzureFirewallManagementSubnet')
output vnetAddressPrefixes array = vNet.properties.addressSpace.addressPrefixes
output routeTableName string = routeTable.name
