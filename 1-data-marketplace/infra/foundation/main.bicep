@description('The kit identifier to append to the resources names')
param kitIdentifier string
@description('The location of the resources deployed. Default to same as resource group')
param location string
@description('The suffix to append to the resources names. Composed of the short location and the environment')
param resourceInfix string
@description('The suffix to append to the resources names. Default to resource group name')
param resourceSuffix string
@secure()
@description('The password for the jumpbox')
param jumpServerAdminPassword string
param vaultName string
param commonResourceTags object
@description('The offer tier')
param offerTier string
param crossTenant bool

var abbreviations = loadJsonContent('../../abbreviations.json')

var offerTierConfiguration = {
  basic: {
    aksSkuName: 'Basic'
    aksSkuTier: 'Free'
    bastionSkuName: 'Basic'
    firewallSkuTier: 'Basic'
    jumpboxSize: 'Standard_B2ms'
    acrSkuName: 'Basic'
  }
  standard: {
    aksSkuName: 'Basic'
    aksSkuTier: 'Paid'
    bastionSkuName: 'Standard'
    firewallSkuTier: 'Standard'
    jumpboxSize: 'Standard_B2ms'
    acrSkuName: 'Premium'
  }
}

module network 'vnet.bicep' = {
  name: 'foundation-network'
  params: {
    name: '${abbreviations.networkVirtualNetworks}${resourceInfix}-${kitIdentifier}-${resourceSuffix}'
    routeTableName: '${abbreviations.networkRouteTables}${resourceInfix}-${kitIdentifier}-afw-${resourceSuffix}'
    location: location
    commonResourceTags: commonResourceTags
  }
}

module keyVault 'keyvault.bicep' = {
  name: 'foundation-keyvault'
  params: {
    commonResourceTags: commonResourceTags
    location: location
    privateEndpointSubnetId: network.outputs.endpointsSubnetId
    vaultName: vaultName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

module monitoring 'monitoring.bicep' = {
  name: 'foundation-monitoring'
  params: {
    logAnaltycsWorkspaceName: '${abbreviations.operationalInsightsWorkspaces}${resourceInfix}-${kitIdentifier}-mon-${resourceSuffix}'
    appInsightsName: '${abbreviations.insightsComponents}${resourceInfix}-${kitIdentifier}-mon-${resourceSuffix}'
    location: location
    commonResourceTags: commonResourceTags
  }
}

module firewall 'firewall.bicep' = {
  name: 'foundation-firewall'
  params: {
    publicIpName: '${abbreviations.networkPublicIPAddresses}${resourceInfix}-${kitIdentifier}-afw-${resourceSuffix}'
    managementPublicIpName: '${abbreviations.networkPublicIPAddresses}${resourceInfix}-${kitIdentifier}-fwmng-${resourceSuffix}'
    name: '${abbreviations.networkAzureFirewalls}${resourceInfix}-${kitIdentifier}-${resourceSuffix}'
    routeTableName: network.outputs.routeTableName
    location: location
    commonResourceTags: commonResourceTags
    firewallSubnetId: network.outputs.firewallSubnetId
    vnetAddressPrefixes: network.outputs.vnetAddressPrefixes
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    firewallManagementSubnetId: network.outputs.firewallManagementSubnetId
    skuTier: offerTierConfiguration[offerTier].firewallSkuTier
  }
}

module bastion 'bastion.bicep' = {
  name: 'foundation-bastion'
  params: {
    name: '${abbreviations.networkBastionHosts}${resourceInfix}-${kitIdentifier}-jmpbx-${resourceSuffix}'
    publicIpName: '${abbreviations.networkPublicIPAddresses}${resourceInfix}-${kitIdentifier}-bas-${resourceSuffix}'
    commonResourceTags: commonResourceTags
    subnetId: network.outputs.bastionSubnetId
    location: location
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    skuName: offerTierConfiguration[offerTier].bastionSkuName
  }
}

module jumpServer 'jumpbox.bicep' = {
  name: 'foundation-aks-jumpbox'
  params: {
    name: '${abbreviations.computeVirtualMachines}-${resourceInfix}-${kitIdentifier}-jmpbx-${resourceSuffix}'
    location: location
    nicName: '${abbreviations.networkNetworkInterfaces}${resourceInfix}-${kitIdentifier}-jmpbx-${resourceSuffix}'
    adminPassword: jumpServerAdminPassword
    subnetId: network.outputs.jumpboxSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    commonResourceTags: commonResourceTags
    keyVaultName: vaultName
    encryptionKeyUri: encryption.outputs.vmEncryptionKeyUri
    vmSize: offerTierConfiguration[offerTier].jumpboxSize
  }
}

module cluster 'aks.bicep' = {
  name: 'foundation-aks-cluster'
  params: {
    name: '${abbreviations.containerServiceManagedClusters}${resourceInfix}-${kitIdentifier}-github-${resourceSuffix}'
    kubeletIdentityName: '${abbreviations.managedIdentityUserAssignedIdentities}${resourceInfix}-${kitIdentifier}-k8-${resourceSuffix}'
    aksIdentityName: '${abbreviations.managedIdentityUserAssignedIdentities}${resourceInfix}-${kitIdentifier}-aks-${resourceSuffix}'
    commonResourceTags: commonResourceTags
    resourceSuffix: resourceSuffix
    location: location
    subnetID: network.outputs.aksSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    skuName: offerTierConfiguration[offerTier].aksSkuName
    skuTier: offerTierConfiguration[offerTier].aksSkuTier
    crossTenant: crossTenant
  }
}

module serviceProviderIdentity 'identity.bicep' = {
  name: 'foundation-identity'
  params: {
    name: '${abbreviations.managedIdentityUserAssignedIdentities}${resourceInfix}-${kitIdentifier}-svcpro-${resourceSuffix}'
  }
}

module encryption 'encryption.bicep' = {
  name: 'foundation-encryption'
  params: {
    identityName: '${abbreviations.managedIdentityUserAssignedIdentities}${resourceInfix}-${kitIdentifier}-kv-${resourceSuffix}'
    commonResourceTags: commonResourceTags
    vaultName: vaultName
    location: location
    spIdentityResourceId: serviceProviderIdentity.outputs.resourceId
    crossTenant: crossTenant
  }
}

output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId
output logAnalyticsWorkspaceName string = monitoring.outputs.logAnalyticsWorkspaceName
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString
output appInsightsInstrumentationKey string = monitoring.outputs.appInsightsInstrumentationKey
output appInsightsResourceId string = monitoring.outputs.appInsightsResourceId
output serviceProviderIdentityResourceId string = serviceProviderIdentity.outputs.resourceId
output endpointsSubnetId string = network.outputs.endpointsSubnetId
output serverFarmsSubnetId string = network.outputs.serverFarmsSubnetId
output appGatewaySubnetId string = network.outputs.agwSubnetId
output vnetId string = network.outputs.vnetId
output uamiEncryptionResourceId string = encryption.outputs.uamiEncryptionResourceId
output keyVaultUri string = encryption.outputs.keyVaultUri
output encryptionKeyName string = encryption.outputs.storageEncryptionKeyName
output clusterName string = cluster.outputs.clusterName
