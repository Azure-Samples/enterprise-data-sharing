@description('The location of the resources deployed. Default to same as resource group')
param location string = resourceGroup().location
@description('Name of the keyvault')
param keyVaultName string
param commonResourceTags object
param identityName string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource keyVaultEncryptionKey 'Microsoft.KeyVault/vaults/keys@2022-07-01' = {
  name: 'storageEncryption'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    kty: 'RSA'
    keySize: 4096
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

resource uamiEncryption 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: commonResourceTags
}

var kvEncryptionUserRole = 'e147488a-f6f5-4113-8e2d-b22465e65bf6'
resource uamiIsEncryptionUserOnKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, uamiEncryption.id, kvEncryptionUserRole)
  scope: keyVault

  properties: {
    principalId: uamiEncryption.properties.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', kvEncryptionUserRole)
    principalType: 'ServicePrincipal'
    description: 'Allows the user assigned managed identity to use the encryption key'
  }
}

output encryptionKeyName string = keyVaultEncryptionKey.name
output uamiEncryptionResourceId string = uamiEncryption.id
