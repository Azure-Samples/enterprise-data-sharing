@description('The location of the resources deployed. Default to same as resource group')
param location string = resourceGroup().location
@description('The URL to call when any event is detected on an instance of the offer')
@secure()
param notificationEndpointUri string
@description('The AAD group object ID corresponding to service principals which will be Owner of the managed resource groups')
param devopsServicePrincipalGroupPrincipalId string
@description('The AAD group object ID corresponding to service principals which will be Key Vault Secrets User on the managed resource groups')
param keyVaultDevopsServicePrincipalGroupPrincipalId string
@description('The environment code')
param now string = utcNow('yyyyMMddTHHmmss')

var abbreviations = loadJsonContent('../../../abbreviations.json')

module managedAppDefinition 'managed-app-definition.bicep' = {
  name: 'managed-app-definition-${now}'
  params: {
    name: '${abbreviations.solutionsApplicationDefinitions}eds-sample'
    location: location
    notificationEndpointUri: notificationEndpointUri
    devopsServicePrincipalGroupPrincipalId: devopsServicePrincipalGroupPrincipalId
    keyVaultDevopsServicePrincipalGroupPrincipalId: keyVaultDevopsServicePrincipalGroupPrincipalId
  }
}

output managedAppDefinitionName string = managedAppDefinition.outputs.name
