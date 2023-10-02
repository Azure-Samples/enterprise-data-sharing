param location string = resourceGroup().location
param commonResourceTags object
param customerClientId string
@secure()
param customerClientSecret string
param withPurview bool
param purviewResourceId string
param purviewPrincipalId string
param keyVaultName string
param uamiEncryptionResourceId string
param sqlAdminGroupObjectId string
param keyVaultUri string
param encryptionKeyName string
param logAnalyticsWorkspaceId string
@description('Sku name for the resource')
param skuName string
param datalakeName string
param name string
param managedRgName string

resource synapseDatalake 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: datalakeName
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
      defaultAction: 'Deny'
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

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  parent: synapseDatalake
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource primary 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  parent: blobService
  name: 'primary'
  properties: {
    publicAccess: 'None'
  }
}

var storageBlobDataReaderRole = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
resource purviewIsBlobDataReaderOnAnalyticsCoManagedDatalake 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (withPurview) {
  name: guid(synapseDatalake.id, purviewPrincipalId, storageBlobDataReaderRole)
  scope: synapseDatalake

  properties: {
    principalId: purviewPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRole)
    description: 'Allow Purview to read blobs from the datalake'
  }
}

var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
resource purviewIsReaderOnAnalyticsCoManagedDatalake 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (withPurview) {
  name: guid(synapseDatalake.id, purviewPrincipalId, readerRoleId)
  scope: synapseDatalake

  properties: {
    principalId: purviewPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    description: 'Allows Purview to read the datalake'
  }
}

var keyEncryptionName = 'synapseEncryption'

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource synapseEncryptionKey 'Microsoft.KeyVault/vaults/keys@2022-07-01' = {
  name: keyEncryptionName
  parent: keyVault

  properties: {
    attributes: {
      enabled: true
    }
    kty: 'RSA'
    keySize: 3072
    rotationPolicy: {
      lifetimeActions: [
        {
          trigger: {
            timeAfterCreate: 'P358D'
          }
          action: {
            type: 'rotate'
          }
        }
        {
          trigger: {
            timeBeforeExpiry: 'P30D'
          }
          action: {
            type: 'Notify'
          }
        }
      ]
      attributes: {
        expiryTime: 'P1Y'
      }
    }
  }
}

resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: name
  location: location
  tags: union(commonResourceTags, { data_classification: 'pii' })

  identity: {
    type: 'SystemAssigned,UserAssigned'
    userAssignedIdentities: {
      '${uamiEncryptionResourceId}': {}
    }
  }

  properties: {
    defaultDataLakeStorage: {
      accountUrl: synapseDatalake.properties.primaryEndpoints.dfs
      filesystem: primary.name
    }

    managedResourceGroupName: managedRgName
    managedVirtualNetwork: 'default'
    managedVirtualNetworkSettings: {
      preventDataExfiltration: true
    }

    trustedServiceBypassEnabled: true
    azureADOnlyAuthentication: true

    purviewConfiguration: withPurview ? {
      purviewResourceId: purviewResourceId
    } : null

    encryption: {
      cmk: {
        kekIdentity: {
          userAssignedIdentity: uamiEncryptionResourceId
        }
        key: {
          keyVaultUrl: synapseEncryptionKey.properties.keyUri
          name: synapseEncryptionKey.name
        }
      }
    }
  }

  resource sqlAdmins 'sqlAdministrators' = {
    name: 'activeDirectory'

    properties: {
      administratorType: 'Group'
      sid: sqlAdminGroupObjectId
      tenantId: tenant().tenantId
    }
  }

  resource workspaceKey 'keys' = {
    name: keyEncryptionName

    properties: {
      isActiveCMK: true
      keyVaultUrl: synapseEncryptionKey.properties.keyUri
    }
  }
}

resource configSynapseWithDatalake 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'config-synapse-datalake-${synapseDatalake.name}'
  location: location
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
        value: synapseWorkspace.name
      }
      {
        name: 'accountName'
        value: synapseDatalake.name
      }
      {
        name: 'accountId'
        secureValue: synapseDatalake.id
      }
      {
        name: 'datalakeEndpointUri'
        value: synapseDatalake.properties.primaryEndpoints.dfs
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

resource configureSynapseRbac 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'config-synapse-rbac'
  location: location
  kind: 'AzureCLI'
  tags: commonResourceTags

  properties: {
    azCliVersion: '2.40.0'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    forceUpdateTag: guid(sqlAdminGroupObjectId, synapseWorkspace.name)
    environmentVariables: [
      {
        name: 'customerClientId'
        secureValue: customerClientId
      }
      {
        name: 'customerClientSecret'
        secureValue: customerClientSecret
      }
      {
        name: 'customerTenantId'
        value: tenant().tenantId
      }
      {
        name: 'subscriptionId'
        value: subscription().subscriptionId
      }
      {
        name: 'workspaceName'
        value: synapseWorkspace.name
      }
      {
        name: 'resourceGroupName'
        value: resourceGroup().name
      }
      {
        name: 'sqlAdminGroupObjectId'
        value: sqlAdminGroupObjectId
      }
    ]
    scriptContent: loadTextContent('configure-synapse-rbac.sh')
  }
}

resource purviewIsReaderOnSynapse 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (withPurview) {
  name: guid(synapseWorkspace.id, purviewPrincipalId, readerRoleId)
  scope: synapseWorkspace

  properties: {
    principalId: purviewPrincipalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalType: 'ServicePrincipal'
    description: 'Allows Purview to read the Synapse workspace'
  }
}

resource synapseDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'synapseDiagSettings'
  scope: synapseWorkspace
  properties: {
    logs: [
      {
        category: 'SynapseRbacOperations'
        enabled: true
      }
      {
        category: 'GatewayApiRequests'
        enabled: true
      }
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
      }
      {
        category: 'BuiltinSqlReqsEnded'
        enabled: true
      }
      {
        category: 'IntegrationPipelineRuns'
        enabled: true
      }
      {
        category: 'IntegrationActivityRuns'
        enabled: true
      }
      {
        category: 'IntegrationTriggerRuns'
        enabled: true
      }
      {
        category: 'SynapseLinkEvent'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'
  }
}

resource auditingSettings 'Microsoft.Synapse/workspaces/auditingSettings@2021-06-01' = {
  name: 'default'
  parent: synapseWorkspace
  properties: {
    auditActionsAndGroups: [
      'APPLICATION_ROLE_CHANGE_PASSWORD_GROUP'
      'BACKUP_RESTORE_GROUP'
      'DATABASE_LOGOUT_GROUP'
      'DATABASE_OBJECT_CHANGE_GROUP'
      'DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP'
      'DATABASE_OBJECT_PERMISSION_CHANGE_GROUP'
      'DATABASE_OPERATION_GROUP'
      'DATABASE_PERMISSION_CHANGE_GROUP'
      'DATABASE_PRINCIPAL_CHANGE_GROUP'
      'DATABASE_PRINCIPAL_IMPERSONATION_GROUP'
      'DATABASE_ROLE_MEMBER_CHANGE_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
      'SCHEMA_OBJECT_ACCESS_GROUP'
      'SCHEMA_OBJECT_CHANGE_GROUP'
      'SCHEMA_OBJECT_OWNERSHIP_CHANGE_GROUP'
      'SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP'
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'USER_CHANGE_PASSWORD_GROUP'
      'BATCH_STARTED_GROUP'
      'BATCH_COMPLETED_GROUP'
    ]
    isAzureMonitorTargetEnabled: true
    isDevopsAuditEnabled: true
    queueDelayMs: 1000
    state: 'Enabled'
  }
}

resource extendedAutidingSettings 'Microsoft.Synapse/workspaces/extendedAuditingSettings@2021-06-01' = {
  name: 'default'
  parent: synapseWorkspace
  properties: {
    auditActionsAndGroups: [
      'APPLICATION_ROLE_CHANGE_PASSWORD_GROUP'
      'BACKUP_RESTORE_GROUP'
      'DATABASE_LOGOUT_GROUP'
      'DATABASE_OBJECT_CHANGE_GROUP'
      'DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP'
      'DATABASE_OBJECT_PERMISSION_CHANGE_GROUP'
      'DATABASE_OPERATION_GROUP'
      'DATABASE_PERMISSION_CHANGE_GROUP'
      'DATABASE_PRINCIPAL_CHANGE_GROUP'
      'DATABASE_PRINCIPAL_IMPERSONATION_GROUP'
      'DATABASE_ROLE_MEMBER_CHANGE_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
      'SCHEMA_OBJECT_ACCESS_GROUP'
      'SCHEMA_OBJECT_CHANGE_GROUP'
      'SCHEMA_OBJECT_OWNERSHIP_CHANGE_GROUP'
      'SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP'
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'USER_CHANGE_PASSWORD_GROUP'
      'BATCH_STARTED_GROUP'
      'BATCH_COMPLETED_GROUP'
    ]
    isAzureMonitorTargetEnabled: true
    isDevopsAuditEnabled: true
    queueDelayMs: 1000
    state: 'Enabled'
  }
  dependsOn: [
    auditingSettings
  ]
}

resource synapseDatalakeClientDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'synapseDatalakeDiagSettings'
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

output workspaceName string = synapseWorkspace.name
output principalId string = synapseWorkspace.identity.principalId
output resourceId string = synapseWorkspace.id
