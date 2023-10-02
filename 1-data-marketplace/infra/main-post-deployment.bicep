param location string = resourceGroup().location
param shortLocation string = ''
param analyticsEnabled bool
param resourceSuffix string
param useExistingSynapse bool
param analyticsSynapseWorkspaceResourceId string
@allowed([
  'tst'
  'prd'
])
param environment string
param analyticsCoManagedServiceProviderDatalakeResourceId string
param customerClientId string
@secure()
param customerClientSecret string
param analyticsCoManagedResourceGroupName string
param customerTenantId string

var commonResourceTags = {
  environment: environment
}

var resourceInfix = '${shortLocation}-${environment}'
module analyticsPostDeployment 'analytics/post-deployment/main.bicep' = if (analyticsEnabled) {
  name: 'analytics-post-deployment'

  params: {
    commonResourceTags: union(commonResourceTags, { mccp_kit: 'analytics' })
    location: location
    resourceInfix: resourceInfix
    resourceSuffix: resourceSuffix
    useExistingSynapse: useExistingSynapse
    analyticsSynapseWorkspaceResourceId: analyticsSynapseWorkspaceResourceId
    coManagedServiceProviderDatalakeResourceId: analyticsCoManagedServiceProviderDatalakeResourceId
    customerClientId: customerClientId
    customerClientSecret: customerClientSecret
    analyticsCoManagedResourceGroupName: analyticsCoManagedResourceGroupName
    customerTenantId: customerTenantId
  }
}
