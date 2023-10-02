#! /bin/bash
set -euo pipefail

az login --service-principal -u $customerClientId -p "$customerClientSecret" -t $customerTenantId --output none
az account set -s $subscriptionId

echo "### Get Private Endpoint $peName connection complete name"
peConnectionName=$(az network private-endpoint-connection list \
--resource-group "$resourceGroupName" \
--name "$resourceName" \
--type "$resourceType" \
--query "[?(properties.privateLinkServiceConnectionState.status == 'Pending') && contains(properties.privateEndpoint.id, '$peReference')].name" \
-o tsv) || peConnectionName=''

if [[ -z "$peConnectionName" ]] ; then

  echo "### No Private Endpoint connection to approve"

else

  echo "### Approve Private Endpoint $peName connection"
  az network private-endpoint-connection approve \
  --name "$peConnectionName" \
  --resource-group "$resourceGroupName" \
  --resource-name="$resourceName" \
  --type "$resourceType" \
  --description "Approved" 

fi
