param location string = resourceGroup().location
param commonResourceTags object
param logAnalyticsWorkspaceId string
param name string 

var datashareAvailableLocations = [
  'australiaeast'
  'canadacentral'
  'centralindia'
  'centralus'
  'eastasia'
  'eastus'
  'eastus2'
  'northeurope'
  'southafricanorth'
  'southcentralus'
  'southeastasia'
  'uksouth'
  'westeurope'
  'westus'
  'westus2'
]

resource dataShareAccount 'Microsoft.DataShare/accounts@2021-08-01' = {
  name: name
  location: contains(datashareAvailableLocations, location) ? location : 'westeurope'
  identity: {
    type: 'SystemAssigned'
  }
  tags: union(commonResourceTags, { data_classification: 'pii' })
}

resource diagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'dataShareAccountDiagSettings'
  scope: dataShareAccount

  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output principalId string = dataShareAccount.identity.principalId
output name string = dataShareAccount.name
