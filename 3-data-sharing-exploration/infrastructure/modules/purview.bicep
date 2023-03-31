param project string
param location string = resourceGroup().location
param deployment_id string

@description('Specify a name for the Azure Purview account.')
var purviewName = 'pview${project}${deployment_id}'
var storageAccountName = '${project}st1${deployment_id}'
var keyVaultName = '${project}kv${deployment_id}'
//https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var storage_blob_data_contributor = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource storage 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageAccountName
}

resource keyvault 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: keyVaultName
}

resource purview 'Microsoft.Purview/accounts@2021-07-01' = {
  name: purviewName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    managedResourceGroupName: '${project}-pview-mrg-${deployment_id}'

  }
}

// Authorize Purview MSI on the KeyVault
resource keyvaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2019-09-01' = {
  parent: keyvault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: purview.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

// Authorize Purview MSI on the Datalake
resource storageRoleAssignment1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, resourceId('Microsoft.Purview/accounts', purviewName))
  properties: {
    principalId: purview.identity.principalId
    roleDefinitionId: storage_blob_data_contributor
    principalType: 'ServicePrincipal'
  }
  scope: storage
}

output purviewAccountName string = purview.name
output purviewCatalogUri string = purview.properties.endpoints.catalog
