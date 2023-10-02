@description('The managed app definition resource name')
param name string
@description('Location of resources')
param location string = resourceGroup().location
@description('The URL which will receive notification about lifecycle of instances of the offer')
@secure()
param notificationEndpointUri string
@description('The AAD group object ID corresponding to service principals which will be Owner of the managed resource groups')
param devopsServicePrincipalGroupPrincipalId string
@description('The AAD group object ID corresponding to service principals which will be Key Vault Secrets User on the managed resource groups')
param keyVaultDevopsServicePrincipalGroupPrincipalId string
@description('The environment code')
@allowed([ 'tst', 'prd' ])
param environmentCode string

var ownerRoleId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
var keyVaultSecretUsersRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource managedApplicationDefinition 'Microsoft.Solutions/applicationDefinitions@2021-07-01' = {
  name: name
  location: location

  properties: {
    lockLevel: 'ReadOnly'
    description: 'This is the Enterprise Data Sharing offer for single tenant usage (${environmentCode})'
    displayName: 'Enterprise Data Sharing single tenant offer (${environmentCode})'
    createUiDefinition: loadJsonContent('createUiDefinition.json')
    mainTemplate: loadJsonContent('mainTemplate.json') // NOTE: generated at build time
    authorizations: [
      {
        principalId: devopsServicePrincipalGroupPrincipalId
        roleDefinitionId: ownerRoleId
      }
      {
        principalId: keyVaultDevopsServicePrincipalGroupPrincipalId
        roleDefinitionId: keyVaultSecretUsersRoleId
      }
    ]
    notificationPolicy: {
      notificationEndpoints: [
        {
          uri: notificationEndpointUri
        }
      ]
    }
    lockingPolicy: {
      allowedActions: [
        'Microsoft.OperationalInsights/workspaces/sharedKeys/action'
      ]
    }
    deploymentPolicy: {
      deploymentMode: 'Incremental'
    }
  }
}

output name string = managedApplicationDefinition.name
