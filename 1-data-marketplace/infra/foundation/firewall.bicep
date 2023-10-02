@description('The location of the resources deployed. Default to same as resource group')
param location string
@description('The route table name where routing configuration is stored')
param routeTableName string
@description('The firewall subnet id to configure the subnet for the firewall')
param firewallSubnetId string
@description('The vnet address prefixes for application rules configuration')
param vnetAddressPrefixes array
@description('The log analytics workspace for tracking resource level events and logs')
param logAnalyticsWorkspaceId string
param commonResourceTags object
@description('The azure firewall management subnet id')
param firewallManagementSubnetId string
@description('The sku tier for the resource')
param skuTier string
param publicIpName string
param managementPublicIpName string
param name string

resource firewallIP 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: publicIpName
  location: location
  tags: commonResourceTags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewallManagementIP 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: managementPublicIpName
  location: location
  tags: commonResourceTags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// FQDN's for AKS
// https://learn.microsoft.com/en-us/azure/aks/limit-egress-traffic
resource firewall 'Microsoft.Network/azureFirewalls@2022-07-01' = {
  name: name
  location: location
  tags: commonResourceTags
  properties: {
    ipConfigurations: [
      {
        name: firewallIP.name
        properties: {
          subnet: {
            id: firewallSubnetId
          }
          publicIPAddress: {
            id: firewallIP.id
          }
        }
      }
    ]
    sku: {
      tier: skuTier
      name: 'AZFW_VNet'
    }
    managementIpConfiguration: {
      name: 'managementIpConfig'
      properties: {
        publicIPAddress: {
          id: firewallManagementIP.id
        }
        subnet: {
          id: firewallManagementSubnetId
        }
      }
    }
    applicationRuleCollections: [
      {
        name: 'allow-aks-github-azure-apis'
        properties: {
          priority: 100
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'Default rule'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                '*.githubusercontent.com'
                'github.com'
                '*.github.com'
                replace(replace(environment().authentication.loginEndpoint, '/', ''), 'https:', '')
                replace(replace(environment().resourceManager, '/', ''), 'https:', '')
                '*.hcp.${location}.azmk8s.io'
                'mcr.microsoft.com'
                '*.data.mcr.microsoft.com'
                'packages.microsoft.com'
                'acs-mirror.azureedge.net'
                '*hub.docker.com'
                '*.docker.com'
                '*.docker.io'
                '*.blob.${environment().suffixes.storage}'
                '*.queue.${environment().suffixes.storage}'
                'ghcr.io'
                '*.ghcr.io'
                '*.pkg.github.com'
                '*.nodejs.org'
                '*registry.npmjs.org'
                'archive.ubuntu.com'
                'ppa.launchpad.net'
                '*.ubuntu.com'
                'proxy.golang.org'
                '*.terraform.io'
                'releases.hashicorp.com'
              ]
              sourceAddresses: vnetAddressPrefixes
            }
            {
              name: 'Ubuntu rule'
              protocols: [
                {
                  protocolType: 'Http'
                  port: 80
                }
              ]
              targetFqdns: [
                'archive.ubuntu.com'
                'ppa.launchpad.net'
                '*.ubuntu.com'
              ]
              sourceAddresses: vnetAddressPrefixes
            }
            {
              name: 'AKS rule'
              protocols: [
                {
                  protocolType: 'Http'
                  port: 80
                }
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              fqdnTags: [
                'AzureKubernetesService'
              ]
              sourceAddresses: [
                '*'
              ]
            }
          ]
        }
      }
      {
        name: 'actions-runner-controller'
        properties: {
          priority: 200
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'docker'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'auth.docker.io'
                'registry-1.docker.io'
                'production.cloudflare.docker.com'
              ]
              sourceAddresses: vnetAddressPrefixes
            }
            {
              name: 'quay.io'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'quay.io'
                '*.quay.io'
              ]
              sourceAddresses: vnetAddressPrefixes
            }
            {
              name: 'runner-tooling'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'nodejs.org'
                'dl.k8s.io'
                'storage.googleapis.com'
              ]
              sourceAddresses: vnetAddressPrefixes
            }
            {
              name: 'analytics-web'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'pypi.python.org'
                'files.pythonhosted.org'
                'pypi.org'
                '*.purview.azure.com'
                'login.windows.net'
                '*.azurewebsites.net'
                '*.applicationinsights.azure.com'
                'api.loganalytics.io'
                'graph.microsoft.com'
                '*.${environment().suffixes.keyvaultDns}'
              ]
              sourceAddresses: vnetAddressPrefixes
            }
            {
              name: 'analytics-db'
              protocols: [
                {
                  protocolType: 'Mssql'
                  port: 1433
                }
              ]
              targetFqdns: [
                '*.sql.azuresynapse.net'
              ]
              sourceAddresses: vnetAddressPrefixes
            }
          ]
        }
      }
      {
        name: 'jumpbox'
        properties: {
          priority: 300
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'az cli'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'aka.ms'
                'azurecliprod.blob.${environment().suffixes.storage}'
                'storage.googleapis.com'
                'azure.microsoft.com'
              ]
              sourceAddresses: vnetAddressPrefixes
            }
            {
              name: 'KApp'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'carvel.dev'
              ]
              sourceAddresses: vnetAddressPrefixes
            }
            {
              name: 'KApp dependencies'
              protocols: [
                {
                  protocolType: 'Http'
                  port: 80
                }
              ]
              targetFqdns: [
                'github.com'
              ]
              sourceAddresses: vnetAddressPrefixes
            }
            {
              name: 'machine'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                '*.blob.storage.azure.net'
                '*.ubuntu.com'
                'api.snapcraft.io'
              ]
              sourceAddresses: vnetAddressPrefixes
            }
            {
              name: 'ops insights'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                '*.handler.control.monitor.azure.com'
                '*.ods.opinsights.azure.com'
              ]
              sourceAddresses: vnetAddressPrefixes
            }
          ]
        }
      }
    ]
  }
}

resource routeTable 'Microsoft.Network/routeTables@2022-05-01' existing = {
  name: routeTableName
}

resource internetThroughFW 'Microsoft.Network/routeTables/routes@2022-05-01' = {
  name: 'to-internet'
  parent: routeTable

  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
    nextHopType: 'VirtualAppliance'
  }
}

resource firewallDiagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'firewallDiagSettings'
  scope: firewall

  properties: {
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: false
      }
    ]
    workspaceId: logAnalyticsWorkspaceId
  }
}
