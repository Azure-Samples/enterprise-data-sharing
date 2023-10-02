targetScope = 'subscription'

param location string = deployment().location
param shortLocation string = ''
param resourceSuffix string
param analyticsEnabled bool
param analyticsUseExistingCoManagedResourceGroup bool
param analyticsExistingCoManagedResourceGroupName string
param useExistingSynapse bool = false
param synapseWorkspaceResourceId string = ''
param customerClientId string = ''
param analyticsPrincipalObjectId string = ''
@secure()
param customerClientSecret string = ''
param withAnalyticsPurview bool = false
param analyticsPurviewPrincipalId string = ''
param analyticsPurviewResourceId string = ''
param analyticsSynapseSqlAdminGroupObjectId string = ''
@allowed([
  'tst'
  'prd'
])
param environment string
param managedResourceGroupName string
param foundationLogAnalyticsName string
param analyticsFunctionAppName string = ''
param analyticsDataShareName string = ''
param offerTier string

var commonResourceTags = {
  environment: environment
}

var resourceInfix = '${shortLocation}-${environment}'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: foundationLogAnalyticsName
  scope: resourceGroup(managedResourceGroupName)
}

module analyticsCoManaged 'analytics/co-managed/main.bicep' = if (analyticsEnabled) {
  name: 'analytics-${resourceSuffix}-co-managed'
  params: {
    kitIdentifier: 'anc'
    commonResourceTags: union(commonResourceTags, { mccp_kit: 'analytics' })
    location: location
    resourceInfix: resourceInfix
    resourceSuffix: resourceSuffix
    useExistingSynapse: useExistingSynapse
    synapseWorkspaceResourceId: synapseWorkspaceResourceId
    synapseSqlAdminGroupObjectId: analyticsSynapseSqlAdminGroupObjectId
    customerClientId: customerClientId
    analyticsPrincipalObjectId: analyticsPrincipalObjectId
    customerClientSecret: customerClientSecret
    withPurview: withAnalyticsPurview
    purviewPrincipalId: analyticsPurviewPrincipalId
    purviewResourceId: analyticsPurviewResourceId
    managedResourceGroupName: managedResourceGroupName
    useExistingCoManagedResourceGroup: analyticsUseExistingCoManagedResourceGroup
    existingCoManagedResourceGroupName: analyticsExistingCoManagedResourceGroupName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
    dataShareName: analyticsDataShareName
    functionAppName: analyticsFunctionAppName
    offerTier: offerTier
  }
}

output analyticsSynapseWorkspaceName string = analyticsEnabled ? analyticsCoManaged.outputs.synapseWorkspaceName : ''
output analyticsSynapseWorkspaceResourceId string = analyticsEnabled ? analyticsCoManaged.outputs.synapseWorkspaceResourceId : ''
output analyticsServiceProviderDatalakeName string = analyticsEnabled ? analyticsCoManaged.outputs.serviceProviderDatalakeName : ''
output analyticsServiceProviderDatalakeResourceId string = analyticsEnabled ? analyticsCoManaged.outputs.serviceProviderDatalakeResourceId : ''
output analyticsCoManagedResourceGroupName string = analyticsEnabled ? analyticsCoManaged.outputs.resourceGroupName : ''
output analyticsKeyVaultName string = analyticsEnabled ? analyticsCoManaged.outputs.keyVaultName : ''
