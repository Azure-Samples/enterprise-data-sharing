param synapseWorkspaceResourceId string

var splitSynapseWorkspaceResourceId = split(synapseWorkspaceResourceId, '/')

// [0]/subscriptions/[2]/resourceGroups/[4]/providers/Microsoft.Synapse/workspaces/[8]

resource existingSynapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' existing = {
  name: splitSynapseWorkspaceResourceId[8]
  scope: resourceGroup(splitSynapseWorkspaceResourceId[2], splitSynapseWorkspaceResourceId[4])
}

output principalId string = existingSynapseWorkspace.identity.principalId
output workspaceName string = existingSynapseWorkspace.name
