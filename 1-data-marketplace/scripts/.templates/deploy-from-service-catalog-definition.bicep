param applicationDefinitionResourceId string
param location string = resourceGroup().location
param environment string = 'tst'
param offerTier string = 'standard'
param principalClientId string
param principalObjectId string

@secure()
param principalSecret string
param analyticsPrincipalClientId string
param analyticsPrincipalObjectId string

@secure()
param analyticsPrincipalSecret string
param customerTenantId string
param analytics object
param crossTenant bool
param applicationResourceName string
param managedResourceGroupId string = ''
param managedIdentity object = {}

var mrgId = (empty(managedResourceGroupId) ? '${subscription().id}/resourceGroups/${take('${resourceGroup().name}-${uniqueString(resourceGroup().id)}${uniqueString(applicationResourceName)}', 90)}' : managedResourceGroupId)

resource applicationResource 'Microsoft.Solutions/applications@2021-07-01' = {
  location: location
  kind: 'ServiceCatalog'
  name: applicationResourceName
  identity: (empty(managedIdentity) ? null : managedIdentity)
  properties: {
    managedResourceGroupId: mrgId
    applicationDefinitionId: applicationDefinitionResourceId
    parameters: {
      location: {
        value: location
      }
      environment: {
        value: environment
      }
      offerTier: {
        value: offerTier
      }
      principalClientId: {
        value: principalClientId
      }
      principalObjectId: {
        value: principalObjectId
      }
      principalSecret: {
        value: principalSecret
      }
      analyticsPrincipalClientId: {
        value: analyticsPrincipalClientId
      }
      analyticsPrincipalObjectId: {
        value: analyticsPrincipalObjectId
      }
      analyticsPrincipalSecret: {
        value: analyticsPrincipalSecret
      }
      customerTenantId: {
        value: customerTenantId
      }
      analytics: {
        value: analytics
      }
      crossTenant: {
        value: crossTenant
      }
    }
  }
}
