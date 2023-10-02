@description('The location of the resources deployed. Default to same as resource group')
param location string = resourceGroup().location
param identityName string
@description('Name of the keyvault')
param vaultName string
param spIdentityResourceId string
param commonResourceTags object
param crossTenant bool

var storageEncryptionKeyName = 'storageEncryption'
var vmEncryptionKeyName = 'vmEncryption'
var keysEncryptionName = [storageEncryptionKeyName, vmEncryptionKeyName]
var keyRotationPolicy = {
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
        type: 'notify'
      }
    }
  ]
  attributes: {
    expiryTime: 'P1Y'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: vaultName
}

resource keyScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'create-key-${join(keysEncryptionName,'-')}'
  location: location
  tags: commonResourceTags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${spIdentityResourceId}': {}
    }
  }
  properties: {
    azCliVersion: '2.40.0'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    timeout: 'PT30M'
    environmentVariables: [
      {
        name: 'VAULT_NAME'
        value: vaultName
      }
      {
        name: 'KEYS_NAME'
        value: join(keysEncryptionName,' ')
      }
      {
        name: 'KEY_ROTATION_POLICY'
        value: string(keyRotationPolicy)
      }
    ]
    scriptContent: '''
      # Create an encryption key with automatic rotation policy
      # see https://learn.microsoft.com/en-us/azure/key-vault/keys/how-to-configure-key-rotation
      # Provide key ids in the deployment script outputs formatted as
      # { "key1": { "id": key1_id}, "key2": {"id": key2_id}, ...}
      echo '{}' > $AZ_SCRIPTS_OUTPUT_PATH
      for key_name in ${KEYS_NAME}; do
        key_exist=$(az keyvault key list --vault-name ${VAULT_NAME} --query "[?name==\`${key_name}\`].name" -o tsv) || key_exist=''
        if [ -z "${key_exist}" ]; then
          az keyvault key create \
            --vault-name ${VAULT_NAME} \
            -n ${key_name} \
            --kty RSA --size 4096
          az keyvault key rotation-policy update \
            --vault-name ${VAULT_NAME} \
            -n ${key_name} \
            --value "${KEY_ROTATION_POLICY}"
        fi
        key_id=$(az keyvault key show --vault-name ${VAULT_NAME} -n ${key_name} --query "{kid: key.kid}")
        output=$(<$AZ_SCRIPTS_OUTPUT_PATH)
        echo "$output" | jq -c --arg key ${key_name} --argjson id "${key_id}" '.[$key]=$id' > $AZ_SCRIPTS_OUTPUT_PATH
      done
    '''
  }
}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: commonResourceTags
}

var kvEncryptionUserRole = 'e147488a-f6f5-4113-8e2d-b22465e65bf6'
resource uamiIsEncryptionUserOnKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, uami.id, kvEncryptionUserRole)
  scope: keyVault
  properties: {
    principalId: uami.properties.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', kvEncryptionUserRole)
    delegatedManagedIdentityResourceId: crossTenant ? uami.id : null
    principalType: 'ServicePrincipal'
  }
}

output storageEncryptionKeyName string = storageEncryptionKeyName
output vmEncryptionKeyUri string = keyScript.properties.outputs[vmEncryptionKeyName].kid
output keyVaultUri string = keyVault.properties.vaultUri
output uamiEncryptionResourceId string = uami.id
