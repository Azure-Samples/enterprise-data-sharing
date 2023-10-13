@description('The kit identifier to append to the resources names')
param location string = resourceGroup().location
param synapseWorkspaceName string
param customerClientId string
@secure()
param customerClientSecret string
param synapsePrincipalId string
param purviewPrincipalId string
param uamiEncryptionResourceId string
param keyVaultUri string
param encryptionKeyName string
param commonResourceTags object
param logAnalyticsWorkspaceId string
param useExistingSynapse bool
param analyticsPrincipalId string
param functionAppPrincipalId string
param datasharePrincipalId string
@description('The sku name for the resource')
param skuName string
param name string

resource serviceProviderDataLake 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: name
  location: location
  tags: union(commonResourceTags, { data_classification: 'pii' })
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiEncryptionResourceId}': {}
    }
  }
  properties: {
    isHnsEnabled: true
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    encryption: {
      identity: {
        userAssignedIdentity: uamiEncryptionResourceId
      }
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Keyvault'
      keyvaultproperties: {
        keyname: encryptionKeyName
        keyvaulturi: keyVaultUri
      }
    }
  }
}

var storageBlobDataContributorRole = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
resource synapseIsBlobDataContributorOnServiceProviderDatalake 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceProviderDataLake.id, synapsePrincipalId, storageBlobDataContributorRole)
  scope: serviceProviderDataLake
  properties: {
    principalId: synapsePrincipalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRole)
    principalType: 'ServicePrincipal'
  }
}

resource configSynapseWithServiceProviderDatalake 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (!useExistingSynapse) {
  name: 'config-synapse-${serviceProviderDataLake.name}'
  location: location
  dependsOn: [ synapseIsBlobDataContributorOnServiceProviderDatalake ]
  tags: commonResourceTags
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.40.0'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'subscriptionId'
        value: subscription().subscriptionId
      }
      {
        name: 'resourceGroupName'
        value: resourceGroup().name
      }
      {
        name: 'workspaceName'
        value: synapseWorkspaceName
      }
      {
        name: 'accountName'
        value: serviceProviderDataLake.name
      }
      {
        name: 'accountId'
        secureValue: serviceProviderDataLake.id
      }
      {
        name: 'datalakeEndpointUri'
        value: serviceProviderDataLake.properties.primaryEndpoints.dfs
      }
      {
        name: 'clientId'
        secureValue: customerClientId
      }
      {
        name: 'clientSecret'
        secureValue: customerClientSecret
      }
      {
        name: 'tenantId'
        secureValue: tenant().tenantId
      }
    ]
    scriptContent: loadTextContent('add-config-synapse.sh')
  }
}

var storageBlobDataReaderRole = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
resource purviewIsBlobDataReaderOnAnalyticsCoManagedServiceProviderDatalake 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceProviderDataLake.id, purviewPrincipalId, storageBlobDataReaderRole)
  scope: serviceProviderDataLake
  properties: {
    principalId: purviewPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRole)
  }
}

var dataLakeReaderRole = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
resource purviewIsReaderOnAnalyticsCoManagedServiceProviderDatalake 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceProviderDataLake.id, purviewPrincipalId, dataLakeReaderRole)
  scope: serviceProviderDataLake
  properties: {
    principalId: purviewPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', dataLakeReaderRole)
  }
}

var ownerRoleId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
resource functionIsOwnerOfServiceProviderDatalake 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceProviderDataLake.id, functionAppPrincipalId, ownerRoleId)
  scope: serviceProviderDataLake

  properties: {
    principalId: functionAppPrincipalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', ownerRoleId)
    principalType: 'ServicePrincipal'
  }
}

var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
resource functionInManagedRgIsStorageBlobDataOwnerOfServiceProviderDatalake 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceProviderDataLake.id, functionAppPrincipalId, storageBlobDataOwnerRoleId)
  scope: serviceProviderDataLake

  properties: {
    principalId: functionAppPrincipalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalType: 'ServicePrincipal'
  }
}

resource dataShareInManagedRgIsStorageBlobDataContributorOnServiceProviderDatalake 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceProviderDataLake.id, datasharePrincipalId, storageBlobDataContributorRole)
  scope: serviceProviderDataLake

  properties: {
    principalId: datasharePrincipalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRole)
    principalType: 'ServicePrincipal'
  }
}

resource analyticsCustomerPrincipalIsStorageBlobDataOwnerOnServiceProviderDatalake 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceProviderDataLake.id, analyticsPrincipalId, storageBlobDataOwnerRoleId)
  scope: serviceProviderDataLake

  properties: {
    principalId: analyticsPrincipalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalType: 'ServicePrincipal'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  parent: serviceProviderDataLake
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource datalakeBlobDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'datalakeBlobDiagSettings'
  scope: blobService

  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

output id string = serviceProviderDataLake.id
output name string = serviceProviderDataLake.name
