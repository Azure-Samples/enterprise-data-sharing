param name string
param location string
param tags object

resource purview 'Microsoft.Purview/accounts@2021-12-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    cloudConnectors: {}
    publicNetworkAccess: 'Enabled'
    managedResourceGroupName: 'mrg-${name}'
    managedResourcesPublicNetworkAccess: 'Enabled'
    managedEventHubState: 'Disabled'
  }
}

output id string = purview.id
output principalId string = purview.identity.principalId
output purviewName string = purview.name
