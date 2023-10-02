param location string = resourceGroup().location
@description('The suffix to append to the resources names. Composed of the short location and the environment')
param vaultName string
param appInsightsConnectionString string
param logAnalyticsWorkspaceId string
param endpointsSubnetId string
param serverFarmsSubnetId string
param commonResourceTags object
param datashareName string
param uamiEncryptionResourceId string
param keyVaultUri string
param encryptionKeyName string
param functionAppName string
param storageName string
param hostingPlanName string
param privateEndpointPrefix string
param privateLinkServicePrefix string
param crossTenant bool

var storageUrl = environment().suffixes.storage
var privateDnsZoneBlobName = 'privatelink.blob.${storageUrl}'
var privateDnsZoneQueueName = 'privatelink.queue.${storageUrl}'
var privateDnsZoneTableName = 'privatelink.table.${storageUrl}'
var privateDnsZoneFileName = 'privatelink.file.${storageUrl}'
@description('The sku kind for the resource')
param skuKind string
@description('The sku name for the resource')
param skuName string
@description('The sku tier for the resource')
param skuTier string

resource privateDnsZoneBlob 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneBlobName
}

resource privateDnsZoneQueue 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneQueueName
}

resource privateDnsZoneTable 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneTableName
}

resource privateDnsZoneFile 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneFileName
}

resource datashare 'Microsoft.DataShare/accounts@2021-08-01' existing = {
  name: datashareName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageName
  location: location
  tags: union(commonResourceTags, { data_classification: 'pii' })
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiEncryptionResourceId}': {}
    }
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
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

resource functionStorageBlobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  name: 'default'
  parent: storageAccount
}

resource functionStorageQueueService 'Microsoft.Storage/storageAccounts/queueServices@2022-09-01' = {
  name: 'default'
  parent: storageAccount
}

resource functionStorageTableService 'Microsoft.Storage/storageAccounts/tableServices@2022-09-01' = {
  name: 'default'
  parent: storageAccount
}

resource functionStorageFileService 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = {
  name: 'default'
  parent: storageAccount
}

resource functionContentShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  name: toLower(functionAppName)
  parent: functionStorageFileService

  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 5
  }
}

resource privateEndpointBlob 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: '${privateEndpointPrefix}blob-${storageAccount.name}'
  location: location
  tags: commonResourceTags
  properties: {
    subnet: {
      id: endpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${privateLinkServicePrefix}blob-${storageAccount.name}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }

  resource zoneGroup 'privateDnsZoneGroups@2022-05-01' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-blob'
          properties: {
            privateDnsZoneId: privateDnsZoneBlob.id
          }
        }
      ]
    }
  }
}

resource privateEndpointQueue 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: '${privateEndpointPrefix}queue-${storageAccount.name}'
  location: location
  tags: commonResourceTags
  properties: {
    subnet: {
      id: endpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${privateLinkServicePrefix}queue-${storageAccount.name}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'queue'
          ]
        }
      }
    ]
  }

  resource zoneGroup 'privateDnsZoneGroups@2022-05-01' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-queue'
          properties: {
            privateDnsZoneId: privateDnsZoneQueue.id
          }
        }
      ]
    }
  }
}

resource privateEndpointTable 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: '${privateEndpointPrefix}table-${storageAccount.name}'
  location: location
  tags: commonResourceTags
  properties: {
    subnet: {
      id: endpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${privateLinkServicePrefix}table-${storageAccount.name}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'table'
          ]
        }
      }
    ]
  }

  resource zoneGroup 'privateDnsZoneGroups@2022-09-01' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-table'
          properties: {
            privateDnsZoneId: privateDnsZoneTable.id
          }
        }
      ]
    }
  }
}

resource privateEndpointFile 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: '${privateEndpointPrefix}file-${storageAccount.name}'
  location: location
  tags: commonResourceTags
  properties: {
    subnet: {
      id: endpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${privateLinkServicePrefix}file-${storageAccount.name}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }

  resource zoneGroup 'privateDnsZoneGroups@2022-09-01' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-file'
          properties: {
            privateDnsZoneId: privateDnsZoneFile.id
          }
        }
      ]
    }
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: hostingPlanName
  location: location
  tags: commonResourceTags
  kind: skuKind
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'

  dependsOn: [
    privateEndpointBlob
    privateEndpointBlob::zoneGroup
    privateEndpointFile
    privateEndpointFile::zoneGroup
    privateEndpointQueue
    privateEndpointQueue::zoneGroup
    privateEndpointTable
    privateEndpointTable::zoneGroup
  ]

  identity: {
    type: 'SystemAssigned'
  }

  tags: union(commonResourceTags, { data_classification: 'pii' })
  properties: {
    virtualNetworkSubnetId: serverFarmsSubnetId
    vnetRouteAllEnabled: true
    serverFarmId: hostingPlan.id
    siteConfig: {
      linuxFxVersion: 'python|3.9'
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      http20Enabled: true
    }
    clientCertEnabled: false
    httpsOnly: true
  }
}

module appSettings 'func-app-settings.bicep' = {
  name: 'analytics-managed-func-app-settings'
  params: {
    functionAppName: functionApp.name
    existingSettings: list(resourceId('Microsoft.Web/sites/config', functionApp.name, 'appsettings'), '2022-03-01').properties
    appSettings: {
      AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
      WEBSITE_CONTENTSHARE: functionContentShare.name
      FUNCTIONS_EXTENSION_VERSION: '~4'
      FUNCTIONS_WORKER_RUNTIME: 'python'
      WEBSITE_CONTENTOVERVNET: '1'
      AZURE_CLIENT_ID: '@Microsoft.KeyVault(VaultName=${vaultName};SecretName=analytics-sp-client-id)'
      AZURE_TENANT_ID: '@Microsoft.KeyVault(VaultName=${vaultName};SecretName=tenantId)'
      AZURE_CLIENT_SECRET: '@Microsoft.KeyVault(VaultName=${vaultName};SecretName=analytics-sp-client-secret)'
    }
  }
}

resource funcDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'funcDiagSettings'
  scope: functionApp

  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        enabled: true
        category: 'FunctionAppLogs'
      }
    ]
  }
}

resource funcAspDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'funcAspDiagSettings'
  scope: hostingPlan

  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: vaultName
}

var kvSecretsUserRole = '4633458b-17de-408a-b874-0445c86b69e6'
resource functionIsSecretUserOnKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, functionApp.id, kvSecretsUserRole)
  scope: keyVault

  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsUserRole)
    delegatedManagedIdentityResourceId: crossTenant ? functionApp.id : null
    principalType: 'ServicePrincipal'
    description: 'Allows the function app to read secrets from the key vault'
  }
}

var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
resource functionIsContributorOnDatashare 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(datashare.id, functionApp.id, contributorRoleId)
  scope: datashare

  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    delegatedManagedIdentityResourceId: crossTenant ? functionApp.id : null
    principalType: 'ServicePrincipal'
    description: 'Allows the function app to manage the datashare'
  }
}

resource funcBlobDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'funcBlobDiagSettings'
  scope: functionStorageBlobService

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

resource funcQueueDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'funcQueueDiagSettings'
  scope: functionStorageQueueService

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

resource funcTableDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'funcTableDiagSettings'
  scope: functionStorageTableService

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

resource funcFileDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'funcFileDiagSettings'
  scope: functionStorageFileService

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

output name string = functionApp.name
output principalId string = functionApp.identity.principalId
output id string = functionApp.id
