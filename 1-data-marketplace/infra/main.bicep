@description('The location of the resources deployed. Default to same as resource group')
param location string = resourceGroup().location
param shortLocation string = ''
@secure()
param jumpServerAdminPassword string
@allowed([
  'tst'
  'prd'
])
param environment string
param offerTier string
param crossTenant bool

var abbreviations = loadJsonContent('../abbreviations.json')
var resourceInfix = '${shortLocation}-${environment}'
var resourceSuffix = take(uniqueString(resourceGroup().name), 6)
var vaultName = '${abbreviations.keyVaultVaults}${resourceInfix}-fnd-${resourceSuffix}'

module foundation 'foundation/main.bicep' = {
  name: 'foundation'

  params: {
    kitIdentifier: 'fnd'
    jumpServerAdminPassword: jumpServerAdminPassword
    location: location
    resourceInfix: resourceInfix
    vaultName: vaultName
    resourceSuffix: resourceSuffix
    commonResourceTags: { eds_area: 'foundation' }
    offerTier: offerTier
    crossTenant: crossTenant
  }
}

module analyticsManaged 'analytics/managed/main.bicep' = {
  name: 'analytics'

  params: {
    kitIdentifier: 'anm'
    location: location
    resourceInfix: resourceInfix
    commonResourceTags: { eds_area: 'analytics' }
    appInsightsConnectionString: foundation.outputs.appInsightsConnectionString
    logAnalyticsWorkspaceId: foundation.outputs.logAnalyticsWorkspaceId
    resourceSuffix: resourceSuffix
    endpointsSubnetId: foundation.outputs.endpointsSubnetId
    serverFarmsSubnetId: foundation.outputs.serverFarmsSubnetId
    vaultName: vaultName
    keyVaultUri: foundation.outputs.keyVaultUri
    encryptionKeyName: foundation.outputs.encryptionKeyName
    uamiEncryptionResourceId: foundation.outputs.uamiEncryptionResourceId
    offerTier: offerTier
    crossTenant: crossTenant
  }
}

output resourceSuffix string = resourceSuffix
output customerTenantId string = subscription().tenantId
output foundationKeyVaultName string = vaultName
output foundationClusterName string = foundation.outputs.clusterName
output foundationLogAnalyticsWorkspaceName string = foundation.outputs.logAnalyticsWorkspaceName
output appInsightsResourceId string = foundation.outputs.appInsightsResourceId
output analyticsFunctionAppName string = analyticsManaged.outputs.functionAppName
output analyticsFunctionAppPrincipalId string = analyticsManaged.outputs.functionAppPrincipalId
output analyticsDataShareName string = analyticsManaged.outputs.dataShareName
