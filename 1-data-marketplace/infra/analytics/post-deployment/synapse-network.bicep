param location string = resourceGroup().location
param useExistingSynapse bool
param analyticsSynapseResourceId string
param commonResourceTags object
param customerClientId string
@secure()
param customerClientSecret string
param analyticsCoManagedResourceGroupName string
param customerTenantId string
param vnetName string
param privateEndpointsNamePrefix string
param privateLinkServiceNamePrefix string

var workspaceSynapseName = last(split(analyticsSynapseResourceId, '/'))

resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  name: vnetName
}

resource endpointsSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' existing = {
  name: 'endpoints'
  parent: vnet
}

resource synapaseSqlOnDemandPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.sql.azuresynapse.net'
  scope: resourceGroup()
}

resource sqlOnDemandPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-05-01' = {
  name: '${privateEndpointsNamePrefix}synapse-sql-ondemand'
  location: location
  tags: commonResourceTags

  properties: {
    subnet: {
      id: endpointsSubnet.id
    }
    manualPrivateLinkServiceConnections: [
      {
        name: '${privateLinkServiceNamePrefix}-synapse-sql-ondemand'
        properties: {
          groupIds: [
            'sqlOnDemand'
          ]
          privateLinkServiceId: analyticsSynapseResourceId
          requestMessage: 'Please Approve the connection for the Enterprise Data Sharing Platform'
        }
      }
    ]
  }

  resource sqlOnDemandePrivateEndpointZoneGroup 'privateDnsZoneGroups@2022-05-01' = {
    name: 'default'

    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-synapse-sql-on-demand'
          properties: {
            privateDnsZoneId: synapaseSqlOnDemandPrivateDnsZone.id
          }
        }
      ]
    }
  }
}

resource approvePeConnectionSynapse 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (!useExistingSynapse) {
  name: 'approve-${sqlOnDemandPrivateEndpoint.name}'
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
        value: sqlOnDemandPrivateEndpoint.name
      }
      {
        name: 'resourceName'
        value: workspaceSynapseName
      }
      {
        name: 'resourceGroupName'
        value: analyticsCoManagedResourceGroupName
      }
      {
        name: 'resourceType'
        value: 'Microsoft.Synapse/workspaces'
      }
      {
        name: 'peReference'
        value: 'sql'
      }
    ]
    scriptContent: loadTextContent('approve-pe.sh')
  }
}
