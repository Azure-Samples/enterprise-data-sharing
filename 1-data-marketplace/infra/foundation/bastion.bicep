@description('The ID of the subnet to which the bastion will be added')
param subnetId string
@description('The location of the resources deployed. Default to same as resource group')
param location string = resourceGroup().location
@description('The log analytics workspace for tracking resource level events and logs')
param logAnalyticsWorkspaceId string
param commonResourceTags object
@description('The sku name of the resource')
param skuName string
param publicIpName string
param name string

resource bastionIP 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: publicIpName
  location: location
  tags: commonResourceTags
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2022-01-01' = {
  name: name
  location: location
  tags: commonResourceTags
  sku: {
    name: skuName
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: bastionIP.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    enableTunneling: skuName == 'Standard'
  }
}

resource bastionDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'bastionDiagSettings'
  scope: bastion
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
