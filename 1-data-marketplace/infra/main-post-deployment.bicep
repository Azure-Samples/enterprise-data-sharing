param location string = resourceGroup().location
param shortLocation string = ''
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
module analyticsPostDeployment 'analytics/post-deployment/main.bicep' = {
  name: 'analytics-post-deployment'

  params: {
    commonResourceTags: commonResourceTags
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
