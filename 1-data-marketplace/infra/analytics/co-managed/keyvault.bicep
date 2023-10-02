param location string
param commonResourceTags object
param logAnalyticsWorkspaceId string
param functionAppPrincipalId string
param analyticsPrincipalObjectId string
param name string

resource analyticsVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: union(commonResourceTags, { data_classification: 'other' })
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    tenantId: subscription().tenantId
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 7
  }
}

var keyvaultSecretUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
resource functionAppIsSecretUserOnKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(analyticsVault.id, functionAppPrincipalId, keyvaultSecretUserRoleId)
  scope: analyticsVault

  properties: {
    principalId: functionAppPrincipalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', keyvaultSecretUserRoleId)
    principalType: 'ServicePrincipal'
  }
}

var keyvaultSecretOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
resource analyticsSPIsSecretOfficerOnKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(analyticsVault.id, analyticsPrincipalObjectId, keyvaultSecretOfficerRoleId)
  scope: analyticsVault

  properties: {
    principalId: analyticsPrincipalObjectId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', keyvaultSecretOfficerRoleId)
    principalType: 'ServicePrincipal'
  }
}

resource keyVaultDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'keyVaultDiagSettings'
  scope: analyticsVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
      {
        categoryGroup: 'audit'
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

output keyVaultName string = analyticsVault.name
output keyVaultUri string = analyticsVault.properties.vaultUri
