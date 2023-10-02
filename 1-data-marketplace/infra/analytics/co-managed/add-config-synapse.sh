#! /bin/bash
set -euo pipefail

echo "### Login to Azure"
az login --service-principal -u ${clientId} -t ${tenantId} -p "${clientSecret}" --output none
az account set --subscription ${subscriptionId}

addFirewallRule() {
  echo "### Add synapse workspace firewall rule $1"
  az synapse workspace firewall-rule create \
  --name "$1" \
  --workspace-name "$2" \
  --resource-group "$3" \
  --start-ip-address "$4" \
  --end-ip-address "$4"

  sleep 30
}

removeFirewallRule() {
  echo "### Remove synapse workspace firewall rule $1"
  az synapse workspace firewall-rule delete \
  --name "$1" \
  --workspace-name "$2" \
  --resource-group "$3" \
  --yes
}

approvePEConnection() {
  echo "### Get managed PE $1 complete name"
  managedPEForStorageCompleteName=$(az network private-endpoint-connection list \
  --resource-group $2 \
  --name $3 \
  --type Microsoft.Storage/storageAccounts \
  --query "[?(properties.privateLinkServiceConnectionState.status == 'Pending') && contains(properties.privateEndpoint.id, '$1')].name" \
  -o tsv) || managedPEForStorageCompleteName=''

  if [[ -z "${managedPEForStorageCompleteName}" ]] ; then

    echo "### No managed PE $1 to approve"

  else

    echo "### Approve managed PE $1 connection"
    az network private-endpoint-connection approve \
    --name "${managedPEForStorageCompleteName}" \
    --resource-group "$2" \
    --resource-name="$3" \
    --type Microsoft.Storage/storageAccounts \
    --description "Approved" 

  fi
}

createManagedPE() {
  echo "### Check if managed PE for $1 exists"
  managedPEForStorageExists=$(az synapse managed-private-endpoints list \
    --workspace-name $2 \
    --query "[?(properties.privateLinkResourceId == '$3') && (properties.groupId == '$1')]" \
    -o tsv) || managedPEForStorageExists=''

  if [[ -z ${managedPEForStorageExists} ]]; then

    managedPEForStorageName="managed-pe-$1-$4"
    fileName="$4pe.json"

    echo $fileName

    cat <<EOF >>$fileName
      {
        "privateLinkResourceId": "$3",
        "groupId": "$1"
      }
EOF

    echo "### Create managed PE for $1"
    az synapse managed-private-endpoints create \
    --file @./$fileName \
    --pe-name "${managedPEForStorageName}" \
    --workspace-name "$2"

    rm $fileName

    attempt=1
    maxAttempts=10
    for ((i=$attempt; i<$maxAttempts; i++)); do

      sleep 20
      echo "### Checking provision state of the managed PE (attempt: $attempt/$maxAttempts)"
      isProvisioned=$(az synapse managed-private-endpoints show \
      --workspace-name "$2" \
      --pe-name "${managedPEForStorageName}" \
      --query "contains(properties.provisioningState,'Succeeded')")
      [ "$isProvisioned" == false ] || break

    done

  else 

    echo "### Managed PE for $1 already created"

  fi   
}

hostIP=$(curl ifconfig.me)
firewallRuleName="allowRunnerForConfig${accountName}"

addFirewallRule $firewallRuleName $workspaceName $resourceGroupName $hostIP

fileName="${accountName}link.json"

echo $fileName

cat <<EOF >>$fileName
  {
    "name": "$accountName",
    "type": "Microsoft.Synapse/workspaces/linkedservices",
    "properties": {
        "type": "AzureBlobFS",
        "connectVia": {
            "referenceName": "AutoResolveIntegrationRuntime",
            "type": "IntegrationRuntimeReference"
        },
        "typeProperties": {
            "url": "$datalakeEndpointUri"
        }
    }
  }
EOF

echo "### Create linked service for ${accountName}"
az synapse linked-service create \
--file @./$fileName \
--name="${accountName}" \
--workspace-name "${workspaceName}"

rm $fileName

createManagedPE 'dfs' $workspaceName $accountId $accountName
createManagedPE 'blob' $workspaceName $accountId $accountName

removeFirewallRule $firewallRuleName $workspaceName $resourceGroupName

approvePEConnection 'blob' $resourceGroupName $accountName
approvePEConnection 'dfs' $resourceGroupName $accountName
