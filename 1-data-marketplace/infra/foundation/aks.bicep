targetScope = 'resourceGroup'

param name string
@description('The suffix to append to the resources names')
param resourceSuffix string
@description('The log analytics workspace for tracking resource level events and logs')
param logAnalyticsWorkspaceId string
@description('The location of the resources deployed. Default to same as resource group')
param location string = resourceGroup().location
@description('The ID of the subnet in which the cluster will be added')
param subnetID string
param commonResourceTags object
@description('The sku name for the resource')
param skuName string
@description('The sku tier for the resource')
param skuTier string
param kubeletIdentityName string
param aksIdentityName string
param crossTenant bool

resource kubeletidentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: kubeletIdentityName
  tags: union(commonResourceTags, { data_classification: 'pii' })
  location: location
}

resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: aksIdentityName
  tags: union(commonResourceTags, { data_classification: 'pii' })
  location: location
}

var aksOperatorRole = 'f1a07417-d97a-45cb-824c-7a7467783830'
resource aksManagedIdentityOperatorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kubeletidentity.id, aksIdentity.id, aksOperatorRole)
  scope: kubeletidentity
  properties: {
    principalId: aksIdentity.properties.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', aksOperatorRole)
    delegatedManagedIdentityResourceId: crossTenant ? aksIdentity.id : null
    principalType: 'ServicePrincipal'
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2022-07-01' = {
  name: name
  location: location
  tags: union(commonResourceTags, { data_classification: 'pii' })
  dependsOn: [
    aksManagedIdentityOperatorRole
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aksIdentity.id}': {}
    }
  }

  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    dnsPrefix: resourceSuffix
    nodeResourceGroup: '${resourceGroup().name}-nodes'
    identityProfile: {
      kubeletidentity: {
        resourceId: kubeletidentity.id
        clientId: kubeletidentity.properties.clientId
        objectId: kubeletidentity.properties.principalId
      }
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
      kubeDashboard: {
        enabled: false
      }
    }
    enableRBAC: true
    enablePodSecurityPolicy: false
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
    }
    apiServerAccessProfile: {
      enablePrivateCluster: true
      privateDNSZone: 'system'
      enablePrivateClusterPublicFQDN: false
      disableRunCommand: false
    }
    agentPoolProfiles: [
      {
        name: 'default'
        count: 2
        vmSize: 'Standard_D2s_v3'
        osDiskSizeGB: 50
        osDiskType: 'Ephemeral'
        osType: 'Linux'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: subnetID
      }
    ]
  }
}

resource clusterDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'clusterDiagSettings'
  scope: aks
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'kube-apiserver'
        enabled: true
      }
      {
        category: 'kube-audit'
        enabled: true
      }
      {
        category: 'kube-audit-admin'
        enabled: true
      }
      {
        category: 'kube-controller-manager'
        enabled: true
      }
      {
        category: 'kube-scheduler'
        enabled: true
      }
      {
        category: 'cluster-autoscaler'
        enabled: true
      }
      {
        category: 'cloud-controller-manager'
        enabled: true
      }
      {
        category: 'guard'
        enabled: true
      }
      {
        category: 'csi-azuredisk-controller'
        enabled: true
      }
      {
        category: 'csi-azurefile-controller'
        enabled: true
      }
      {
        category: 'csi-snapshot-controller'
        enabled: true
      }
    ]
  }
}

output clusterIdentityPrincipalID string = aksIdentity.properties.principalId
output kubeletIdentityPrincipalID string = kubeletidentity.properties.principalId
output kubeletIdentityResourceId string = kubeletidentity.id
output clusterName string = aks.name
