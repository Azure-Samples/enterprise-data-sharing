targetScope = 'resourceGroup'

param location string = resourceGroup().location
param environment string = 'tst'
param offerTier string = 'standard'
param principalClientId string
param principalObjectId string
@secure()
param principalSecret string
param analyticsPrincipalClientId string = ''
param analyticsPrincipalObjectId string = ''
@secure()
param analyticsPrincipalSecret string = ''
param customerTenantId string
param analytics object
param baseTime string = utcNow('u')
var secretExpiration = dateTimeToEpoch(dateTimeAdd(baseTime, 'P1Y'))

var resourceSuffix = take(uniqueString(resourceGroup().name), 6)
var allLocations = loadJsonContent('../../../geocodes.json')
var shortLocation = allLocations[location]
var abbreviations = loadJsonContent('../../../abbreviations.json')
var resourceInfix = '${shortLocation}-${environment}-fnd'

resource vault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: '${abbreviations.keyVaultVaults}${resourceInfix}-${resourceSuffix}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    enabledForDiskEncryption: true
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 90
    tenantId: customerTenantId
  }
}

resource deploymentSPClientSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: vault
  name: 'clientSecret'
  properties: {
    value: principalSecret
    attributes: {
      exp: secretExpiration
    }
  }
}

resource deploymentSPClientIdKvSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: vault
  name: 'clientId'
  properties: {
    value: principalClientId
    attributes: {
      exp: secretExpiration
    }
  }
}

resource deploymentSPObjectIdKvSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: vault
  name: 'objectId'
  properties: {
    value: principalObjectId
    attributes: {
      exp: secretExpiration
    }
  }
}

resource customerTenantIdKvSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: vault
  name: 'tenantId'
  properties: {
    value: customerTenantId
    attributes: {
      exp: secretExpiration
    }
  }
}

resource analyticsSPClientSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (analytics.withAnalytics) {
  parent: vault
  name: 'analytics-sp-client-secret'
  properties: {
    value: analyticsPrincipalSecret
    attributes: {
      exp: secretExpiration
    }
  }
}

resource analyticsClientIdKvSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (analytics.withAnalytics) {
  parent: vault
  name: 'analytics-sp-client-id'
  properties: {
    value: analyticsPrincipalClientId
    attributes: {
      exp: secretExpiration
    }
  }
}

resource analyticsObjectIdKvSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (analytics.withAnalytics) {
  parent: vault
  name: 'analytics-sp-object-id'
  properties: {
    value: analyticsPrincipalObjectId
    attributes: {
      exp: secretExpiration
    }
  }
}

resource serviceProviderIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${abbreviations.managedIdentityUserAssignedIdentities}${resourceInfix}-svcpro-${resourceSuffix}'
  location: location
}

var ownerRoleId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
resource spIdentityIsOwnerOfManagedRg 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, serviceProviderIdentity.id, ownerRoleId)
  scope: resourceGroup()

  properties: {
    principalId: serviceProviderIdentity.properties.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', ownerRoleId)
    delegatedManagedIdentityResourceId: serviceProviderIdentity.id
  }
}

var kvAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'
resource spIdentityIsKvAdministrator 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, serviceProviderIdentity.id, vault.id, kvAdministratorRoleId)
  scope: vault

  properties: {
    principalId: serviceProviderIdentity.properties.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', kvAdministratorRoleId)
    delegatedManagedIdentityResourceId: serviceProviderIdentity.id
  }
}

output shortLocation string = shortLocation
output offerTier string = offerTier
output analytics object = analytics
output resourceSuffix string = resourceSuffix
