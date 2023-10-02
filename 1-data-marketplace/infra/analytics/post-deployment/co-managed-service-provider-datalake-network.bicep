param location string
param commonResourceTags object
param coManagedServiceProviderDatalakeResourceId string
param customerClientId string
@secure()
param customerClientSecret string
param analyticsCoManagedResourceGroupName string
param customerTenantId string
param vnetName string
param privateEndpointsNamePrefix string
param privateLinkServicesNamePrefix string
param networkInterfacesNamePrefix string

var coManagedServiceProviderDatalakeName = last(split(coManagedServiceProviderDatalakeResourceId, '/'))
var requestMessageApproval = 'Please Approve the connection for the Enterprise Data Sharing Platform'

resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  name: vnetName
}

resource endpointsSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' existing = {
  name: 'endpoints'
  parent: vnet
}

resource storageBlobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
}

resource storageDfsPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.dfs.${environment().suffixes.storage}'
}

resource coManagedServiceProviderDatalakeBlobPE 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: '${privateEndpointsNamePrefix}blob-${coManagedServiceProviderDatalakeName}'
  location: location
  tags: commonResourceTags

  properties: {
    customNetworkInterfaceName: '${networkInterfacesNamePrefix}pe-blob-${coManagedServiceProviderDatalakeName}'
    subnet: {
      id: endpointsSubnet.id
    }
    manualPrivateLinkServiceConnections: [
      {
        name: '${privateLinkServicesNamePrefix}blob-${coManagedServiceProviderDatalakeName}'
        properties: {
          privateLinkServiceId: coManagedServiceProviderDatalakeResourceId
          requestMessage: requestMessageApproval
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }

  resource dnsZoneGroup 'privateDnsZoneGroups@2022-07-01' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-pe-blob-${coManagedServiceProviderDatalakeName}'
          properties: {
            privateDnsZoneId: storageBlobPrivateDnsZone.id
          }
        }
      ]
    }
  }
}

resource customerDatalakeDfsPE 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: '${privateEndpointsNamePrefix}dfs-${coManagedServiceProviderDatalakeName}'
  location: location
  tags: commonResourceTags

  properties: {
    customNetworkInterfaceName: '${networkInterfacesNamePrefix}pe-dfs-${coManagedServiceProviderDatalakeName}'
    subnet: {
      id: endpointsSubnet.id
    }
    manualPrivateLinkServiceConnections: [
      {
        name: '${privateLinkServicesNamePrefix}dfs-${coManagedServiceProviderDatalakeName}'
        properties: {
          privateLinkServiceId: coManagedServiceProviderDatalakeResourceId
          requestMessage: requestMessageApproval
          groupIds: [
            'dfs'
          ]
        }
      }
    ]
  }

  resource dnsZoneGroup 'privateDnsZoneGroups@2022-07-01' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'link-pe-dfs-${coManagedServiceProviderDatalakeName}'
          properties: {
            privateDnsZoneId: storageDfsPrivateDnsZone.id
          }
        }
      ]
    }
  }
}

resource approvePeConnectionBlob 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'approve-${coManagedServiceProviderDatalakeBlobPE.name}'
  location: location
  tags: commonResourceTags
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.40.0'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'customerClientId'
        value: customerClientId
      }
      {
        name: 'customerClientSecret'
        value: customerClientSecret
      }
      {
        name: 'customerTenantId'
        secureValue: customerTenantId
      }
      {
        name: 'subscriptionId'
        value: subscription().subscriptionId
      }
      {
        name: 'peName'
        value: coManagedServiceProviderDatalakeBlobPE.name
      }
      {
        name: 'resourceName'
        value: coManagedServiceProviderDatalakeName
      }
      {
        name: 'resourceGroupName'
        value: analyticsCoManagedResourceGroupName
      }
      {
        name: 'resourceType'
        value: 'Microsoft.Storage/storageAccounts'
      }
      {
        name: 'peReference'
        value: 'blob'
      }
    ]
    scriptContent: loadTextContent('approve-pe.sh')
  }
}

resource approvePeConnectionDfs 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'approve-${customerDatalakeDfsPE.name}'
  location: location
  tags: commonResourceTags
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.40.0'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'customerClientId'
        value: customerClientId
      }
      {
        name: 'customerClientSecret'
        value: customerClientSecret
      }
      {
        name: 'customerTenantId'
        secureValue: customerTenantId
      }
      {
        name: 'subscriptionId'
        value: subscription().subscriptionId
      }
      {
        name: 'peName'
        value: customerDatalakeDfsPE.name
      }
      {
        name: 'resourceName'
        value: coManagedServiceProviderDatalakeName
      }
      {
        name: 'resourceGroupName'
        value: analyticsCoManagedResourceGroupName
      }
      {
        name: 'resourceType'
        value: 'Microsoft.Storage/storageAccounts'
      }
      {
        name: 'peReference'
        value: 'dfs'
      }
    ]
    scriptContent: loadTextContent('approve-pe.sh')
  }
}
