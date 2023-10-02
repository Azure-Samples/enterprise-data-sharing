param name string

resource serviceProviderIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: name
}

output principalId string = serviceProviderIdentity.properties.principalId
output resourceId string = serviceProviderIdentity.id
