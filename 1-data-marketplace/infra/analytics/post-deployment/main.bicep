param location string = resourceGroup().location
param resourceSuffix string
param useExistingSynapse bool
param analyticsSynapseWorkspaceResourceId string
param commonResourceTags object
@description('The suffix to append to the resources names. Composed of the short location and the environment')
param resourceInfix string
param coManagedServiceProviderDatalakeResourceId string
param customerClientId string
@secure()
param customerClientSecret string
param analyticsCoManagedResourceGroupName string
param customerTenantId string

var abbreviations = loadJsonContent('../../../abbreviations.json')

var vnetName = '${abbreviations.networkVirtualNetworks}${resourceInfix}-fnd-${resourceSuffix}'
module synapsePrivateEndpoint 'synapse-network.bicep' = {
  name: 'analytics-post-deployment-synapse-network'

  params: {
    vnetName: vnetName
    privateEndpointsNamePrefix: abbreviations.networkPrivateEndpoints
    privateLinkServiceNamePrefix: abbreviations.networkPrivateLinkServices
    location: location
    commonResourceTags: commonResourceTags
    useExistingSynapse: useExistingSynapse
    analyticsSynapseResourceId: analyticsSynapseWorkspaceResourceId
    customerClientId: customerClientId
    customerClientSecret: customerClientSecret
    analyticsCoManagedResourceGroupName: analyticsCoManagedResourceGroupName
    customerTenantId: customerTenantId
  }
}

module serviceProviderCoManagedDatalakeNetwork 'co-managed-service-provider-datalake-network.bicep' = {
  name: 'analytics-post-deployment-sp-co-managed-datalake-network'
  params: {
    coManagedServiceProviderDatalakeResourceId: coManagedServiceProviderDatalakeResourceId
    commonResourceTags: commonResourceTags
    location: location
    networkInterfacesNamePrefix: abbreviations.networkNetworkInterfaces
    privateEndpointsNamePrefix: abbreviations.networkPrivateEndpoints
    privateLinkServicesNamePrefix: abbreviations.networkPrivateLinkServices
    vnetName: vnetName
    customerClientId: customerClientId
    customerClientSecret: customerClientSecret
    analyticsCoManagedResourceGroupName: analyticsCoManagedResourceGroupName
    customerTenantId: customerTenantId
  }
}
