@description('The location of the resources deployed. Default to same as resource group')
param location string = resourceGroup().location
@secure()
@description('The password of the jumpserver admin used to manage the AKS cluster')
param adminPassword string
@description('The ID of the subnet in which the management jump server will be added')
param subnetId string
@description('The log analytics workspace for tracking resource level events and logs')
param logAnalyticsWorkspaceId string
@description('A cloud init text to configure the jump server with some tooling')
param cloudInit string = '''
#cloud-config
packages:
 - build-essential
 - procps
 - file
 - linuxbrew-wrapper
 - docker.io
runcmd:
 - curl -sL https://aka.ms/InstallAzureCLIDeb | bash
 - az aks install-cli
 - systemctl start docker
 - systemctl enable docker
 - wget -O- https://carvel.dev/install.sh > install-kapp.sh
 - bash install-kapp.sh

final_message: "cloud init was here"
'''
param jumpboxAdminUsername string = 'jumpserver-admin'
param commonResourceTags object
param keyVaultName string
param encryptionKeyUri string
@description('The vm size for the resource')
param vmSize string
param nicName string
param name string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource nic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: nicName
  location: location
  tags: commonResourceTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

var jumpboxName = name
var jumpboxDiskName = '${jumpboxName}-osdisk'
resource jumpbox 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: jumpboxName
  location: location
  tags: union(commonResourceTags, { data_classification: 'other' })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        name: jumpboxDiskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: jumpboxName
      adminUsername: jumpboxAdminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
      customData: base64(cloudInit)
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

resource jumpboxEncryptionExtension 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  name: 'AzureDiskEncryptionForLinux'
  parent: jumpbox
  dependsOn: [
    azureMonitorLinuxAgentExtension
  ]
  location: location
  tags: commonResourceTags
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type: 'AzureDiskEncryptionForLinux'
    typeHandlerVersion: '1.1'
    autoUpgradeMinorVersion: true
    settings: {
      EncryptionOperation: 'EnableEncryption'
      KeyVaultURL: keyVault.properties.vaultUri
      KeyVaultResourceId: keyVault.id
      KeyEncryptionAlgorithm: 'RSA-OAEP'
      VolumeType: 'All'
      KeyEncryptionKeyURL: encryptionKeyUri
      KekVaultResourceId: keyVault.id
    }
  }
}

module jumpboxCreatedDisk 'jumpbox-disk.bicep' = {
  name: 'jumpbox-disk'
  params: {
    jumpboxDiskName: jumpboxDiskName
  }
  dependsOn: [
    jumpbox
  ]
}

resource jumpboxOsDisk 'Microsoft.Compute/disks@2022-07-02' = {
  name: jumpboxDiskName
  location: location
  tags: commonResourceTags
  properties: {
    creationData: jumpboxCreatedDisk.outputs.creationData
    networkAccessPolicy: 'denyAll'
  }
}

resource azureMonitorLinuxAgentExtension 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  name: 'AzureMonitorLinuxAgent'
  parent: jumpbox
  location: location
  tags: commonResourceTags
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.25'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: logAnalyticsWorkspaceId
    }
  }
}
