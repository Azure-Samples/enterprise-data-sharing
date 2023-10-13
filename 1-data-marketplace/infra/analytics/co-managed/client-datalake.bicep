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
@description('The sku name for the resource')
param skuName string
param name string

resource datalakeClient 'Microsoft.Storage/storageAccounts@2022-09-01' = {
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
resource synapseIsBlobDataContributorOnCustomerDatalake 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(datalakeClient.id, synapsePrincipalId, storageBlobDataContributorRole)
  scope: datalakeClient
  properties: {
    principalId: synapsePrincipalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRole)
  }
}

resource configSynapseWithDatalakeClient 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (!useExistingSynapse) {
  name: 'config-synapse-${datalakeClient.name}'
  location: location
  dependsOn: [ synapseIsBlobDataContributorOnCustomerDatalake ]
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
        value: datalakeClient.name
      }
      {
        name: 'accountId'
        secureValue: datalakeClient.id
      }
      {
        name: 'datalakeEndpointUri'
        value: datalakeClient.properties.primaryEndpoints.dfs
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
resource purviewIsBlobDataReaderOnAnalyticsCoManagedClientDatalake 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(datalakeClient.id, purviewPrincipalId, storageBlobDataReaderRole)
  scope: datalakeClient
  properties: {
    principalId: purviewPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRole)
  }
}

var dataLakeReaderRole = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
resource purviewIsReaderOnAnalyticsCoManagedClientDatalake 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(datalakeClient.id, purviewPrincipalId, dataLakeReaderRole)
  scope: datalakeClient
  properties: {
    principalId: purviewPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', dataLakeReaderRole)
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  parent: datalakeClient
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource datalakeClientBlobDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'datalakeClientBlobDiagSettings'
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
