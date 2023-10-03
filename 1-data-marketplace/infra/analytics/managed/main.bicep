@description('The kit identifier to append to the resources names')
param kitIdentifier string
param location string = resourceGroup().location
@description('The suffix to append to the resources names. Composed of the short location and the environment')
param resourceInfix string
param logAnalyticsWorkspaceId string
param appInsightsConnectionString string
param resourceSuffix string
param endpointsSubnetId string
param serverFarmsSubnetId string
param vaultName string
param commonResourceTags object
param uamiEncryptionResourceId string
param keyVaultUri string
param encryptionKeyName string
@description('The offer tier configuration for the kit')
param offerTier string
param crossTenant bool

var abbreviations = loadJsonContent('../../../abbreviations.json')

var offerTierConfiguration = {
  basic: {
    funcSkuKind: 'linux'
    funcSkuName: 'B1'
    funcSkuTier: 'Basic'
  }
  standard: {
    funcSkuKind: 'linux'
    funcSkuName: 'S1'
    funcSkuTier: 'Standard'
  }
}

module func 'func.bicep' = {
  name: 'analytics-function'

  params: {
    functionAppName: '${abbreviations.webSitesFunctions}${resourceInfix}-${kitIdentifier}-${resourceSuffix}'
    hostingPlanName: '${abbreviations.webServerFarms}${resourceInfix}-${kitIdentifier}-${resourceSuffix}'
    privateEndpointPrefix: abbreviations.networkPrivateEndpoints
    privateLinkServicePrefix: abbreviations.networkPrivateLinkServices
    storageName: replace('${abbreviations.storageStorageAccounts}${resourceInfix}${kitIdentifier}${resourceSuffix}', '-', '')
    commonResourceTags: commonResourceTags
    appInsightsConnectionString: appInsightsConnectionString
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    location: location
    vaultName: vaultName
    endpointsSubnetId: endpointsSubnetId
    serverFarmsSubnetId: serverFarmsSubnetId
    datashareName: datashare.outputs.name
    keyVaultUri: keyVaultUri
    encryptionKeyName: encryptionKeyName
    uamiEncryptionResourceId: uamiEncryptionResourceId
    skuKind: offerTierConfiguration[offerTier].funcSkuKind
    skuName: offerTierConfiguration[offerTier].funcSkuName
    skuTier: offerTierConfiguration[offerTier].funcSkuTier
    crossTenant: crossTenant
  }
}

module datashare 'data-share.bicep' = {
  name: 'analytics-datashare'

  params: {
    name: '${abbreviations.dataShareAccounts}${resourceInfix}-${kitIdentifier}-${resourceSuffix}'
    commonResourceTags: commonResourceTags
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

output functionAppName string = func.outputs.name
output functionAppPrincipalId string = func.outputs.principalId
output dataShareName string = datashare.outputs.name
