param dataShareName string
param functionAppName string
param managedResourceGroupName string

resource datashareInManagedRg 'Microsoft.DataShare/accounts@2021-08-01' existing = {
  name: dataShareName
  scope: resourceGroup(managedResourceGroupName)
}

resource functionInManagedRg 'Microsoft.Web/sites@2022-03-01' existing = {
  name: functionAppName
  scope: resourceGroup(managedResourceGroupName)
}

output functionAppPrincipalId string = functionInManagedRg.identity.principalId
output dataSharePrincipalId string = datashareInManagedRg.identity.principalId
