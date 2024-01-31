targetScope = 'subscription'

@description('The kit identifier to append to the resources names')
param kitIdentifier string
param location string = deployment().location
@description('The suffix to append to the resources names. Composed of the short location and the environment')
param resourceInfix string
param purviewPrincipalId string = ''
param resourceSuffix string
param customerClientId string
@secure()
param customerClientSecret string
param analyticsPrincipalObjectId string
param purviewResourceId string = ''
param useExistingSynapse bool
param useExistingPurview bool
param synapseWorkspaceResourceId string
param commonResourceTags object
param synapseSqlAdminGroupObjectId string
param managedResourceGroupName string
param useExistingCoManagedResourceGroup bool
param existingCoManagedResourceGroupName string
param logAnalyticsWorkspaceId string
param dataShareName string
param functionAppName string
@description('The offer tier configuration for the kit')
param offerTier string

var abbreviations = loadJsonContent('../../../abbreviations.json')

var offerTierConfiguration = {
  basic: {
    serviceProviderDatalakeSkuName: 'Standard_LRS'
    clientDatalakeSkuName: 'Standard_LRS'
    synapseSkuName: 'Standard_LRS'
  }
  standard: {
    serviceProviderDatalakeSkuName: 'Standard_ZRS'
    clientDatalakeSkuName: 'Standard_ZRS'
    synapseSkuName: 'Standard_ZRS'
  }
}

resource analyticsCoManagedRg 'Microsoft.Resources/resourceGroups@2022-09-01' = if (!useExistingCoManagedResourceGroup) {
  name: 'rg-${resourceInfix}-${kitIdentifier}-${resourceSuffix}'
  location: location
  tags: commonResourceTags
}

resource analyticsExistingCoManagedRg 'Microsoft.Resources/resourceGroups@2022-09-01' existing = if (useExistingCoManagedResourceGroup) {
  name: existingCoManagedResourceGroupName
}

var identifiedCoManagedResourceGroupName = useExistingCoManagedResourceGroup ? analyticsExistingCoManagedRg.name : analyticsCoManagedRg.name

module managedResources 'managed-resources.bicep' = {
  name: 'analytics-co-managed-read-managed-resources'
  scope: resourceGroup(identifiedCoManagedResourceGroupName)

  params: {
    managedResourceGroupName: managedResourceGroupName
    dataShareName: dataShareName
    functionAppName: functionAppName
  }
}

module synapseExisting 'existing-synapse.bicep' = if (useExistingSynapse) {
  name: 'analytics-co-managed-existing-synapse'
  scope: resourceGroup(identifiedCoManagedResourceGroupName)

  params: {
    synapseWorkspaceResourceId: synapseWorkspaceResourceId
  }
}

module synapse 'synapse.bicep' = if (!useExistingSynapse) {
  name: 'analytics-co-managed-synapse'
  scope: resourceGroup(identifiedCoManagedResourceGroupName)

  params: {
    name: '${abbreviations.synapseWorkspaces}${resourceInfix}-${kitIdentifier}-${resourceSuffix}'
    managedRgName: '${abbreviations.resourcesManagedResourceGroups}${resourceInfix}-${kitIdentifier}-syn-${resourceSuffix}'
    datalakeName: replace('${abbreviations.dataLakeAnalyticsAccounts}${resourceInfix}${kitIdentifier}syn${resourceSuffix}', '-', '')
    location: location
    customerClientId: customerClientId
    customerClientSecret: customerClientSecret
    purviewResourceId: useExistingPurview ? purviewResourceId : purview.outputs.id
    purviewPrincipalId: useExistingPurview ? purviewPrincipalId : purview.outputs.principalId
    keyVaultName: keyvault.outputs.keyVaultName
    uamiEncryptionResourceId: encryption.outputs.uamiEncryptionResourceId
    commonResourceTags: commonResourceTags
    sqlAdminGroupObjectId: synapseSqlAdminGroupObjectId
    encryptionKeyName: encryption.outputs.encryptionKeyName
    keyVaultUri: keyvault.outputs.keyVaultUri
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    skuName: offerTierConfiguration[offerTier].synapseSkuName
  }
}

module keyvault 'keyvault.bicep' = {
  scope: resourceGroup(identifiedCoManagedResourceGroupName)
  name: 'analytics-keyvault'

  params: {
    name: '${abbreviations.keyVaultVaults}${resourceInfix}-${kitIdentifier}-${resourceSuffix}'
    location: location
    commonResourceTags: commonResourceTags
    functionAppPrincipalId: managedResources.outputs.functionAppPrincipalId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    analyticsPrincipalObjectId: analyticsPrincipalObjectId
  }
}

module encryption 'encryption.bicep' = {
  scope: resourceGroup(identifiedCoManagedResourceGroupName)
  name: 'analytics-encryption'

  params: {
    identityName: '${abbreviations.managedIdentityUserAssignedIdentities}${resourceInfix}-${kitIdentifier}-kv-${resourceSuffix}'
    location: location
    keyVaultName: keyvault.outputs.keyVaultName
    commonResourceTags: commonResourceTags
  }
}

module datalakeClient 'client-datalake.bicep' = {
  scope: resourceGroup(identifiedCoManagedResourceGroupName)
  name: 'analytics-co-managed-client-datalake'

  params: {
    name:  replace('${abbreviations.storageStorageAccounts}${resourceInfix}${kitIdentifier}dlc${resourceSuffix}', '-', '')
    location: location
    commonResourceTags: commonResourceTags
    customerClientId: customerClientId
    customerClientSecret: customerClientSecret
    useExistingSynapse: useExistingSynapse
    synapseWorkspaceName: !empty(synapseWorkspaceResourceId) ? synapseExisting.outputs.workspaceName : synapse.outputs.workspaceName
    synapsePrincipalId: !empty(synapseWorkspaceResourceId) ? synapseExisting.outputs.principalId : synapse.outputs.principalId
    purviewPrincipalId: useExistingPurview ? purviewPrincipalId : purview.outputs.principalId
    keyVaultUri: keyvault.outputs.keyVaultUri
    encryptionKeyName: encryption.outputs.encryptionKeyName
    uamiEncryptionResourceId: encryption.outputs.uamiEncryptionResourceId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    skuName: offerTierConfiguration[offerTier].clientDatalakeSkuName
  }
}

module serviveProviderDatalake 'service-provider-datalake.bicep' = {
  scope: resourceGroup(identifiedCoManagedResourceGroupName)
  name: 'analytics-co-managed-sp-datalake'

  params: {
    name: replace('${abbreviations.storageStorageAccounts}${resourceInfix}${kitIdentifier}dlsp${resourceSuffix}', '-', '')
    location: location
    commonResourceTags: commonResourceTags
    customerClientId: customerClientId
    customerClientSecret: customerClientSecret
    useExistingSynapse: useExistingSynapse
    synapseWorkspaceName: !empty(synapseWorkspaceResourceId) ? synapseExisting.outputs.workspaceName : synapse.outputs.workspaceName
    synapsePrincipalId: !empty(synapseWorkspaceResourceId) ? synapseExisting.outputs.principalId : synapse.outputs.principalId
    purviewPrincipalId: useExistingPurview ? purviewPrincipalId : purview.outputs.principalId
    keyVaultUri: keyvault.outputs.keyVaultUri
    encryptionKeyName: encryption.outputs.encryptionKeyName
    uamiEncryptionResourceId: encryption.outputs.uamiEncryptionResourceId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    analyticsPrincipalId: analyticsPrincipalObjectId
    datasharePrincipalId: managedResources.outputs.dataSharePrincipalId
    functionAppPrincipalId: managedResources.outputs.functionAppPrincipalId
    skuName: offerTierConfiguration[offerTier].serviceProviderDatalakeSkuName
  }
}

module purview 'purview.bicep' = if (useExistingPurview == false) {
  scope: resourceGroup(identifiedCoManagedResourceGroupName)
  name: 'analytics-co-managed-purview'
  params: {
    location: location
    name: '${abbreviations.purviewAccounts}${resourceInfix}-${kitIdentifier}-${resourceSuffix}'
    tags: commonResourceTags
  }
}

output synapseWorkspaceResourceId string = (useExistingSynapse) ? synapseWorkspaceResourceId : synapse.outputs.resourceId
output synapseWorkspaceName string = (useExistingSynapse) ? synapseExisting.outputs.workspaceName : synapse.outputs.workspaceName
output serviceProviderDatalakeName string = serviveProviderDatalake.outputs.name
output serviceProviderDatalakeResourceId string = serviveProviderDatalake.outputs.id
output resourceGroupName string = useExistingCoManagedResourceGroup ? analyticsExistingCoManagedRg.name : analyticsCoManagedRg.name
output keyVaultName string = keyvault.outputs.keyVaultName
output purviewResourceName string = (useExistingPurview) ? purview.outputs.purviewName : last(split(purviewResourceId, '/'))
