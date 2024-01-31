#!/bin/bash
set -euo pipefail

if [ -f ./provision.config.json ]
then
    config=$(jq -r . provision.config.json)
else 
    echo "No provision.config.json file found"
    exit 1
fi


echo "[ℹ️] Generating ARM template from ./offers/service-catalog/infra/mainTemplate.bicep..."
az bicep build --file ../offers/service-catalog/infra/mainTemplate.bicep
echo "[✅] Generated ARM template from ./offers/service-catalog/infra/mainTemplate.bicep."

echo "[ℹ️] Starting deployment of the Service Catalog offer definition..."
definitionDeployment=$(az deployment group create \
    --resource-group "$(jq -r '.definition.resourceGroupName' <<< "$config")" \
    --template-file ../offers/service-catalog/infra/main.bicep \
    --parameters notificationEndpointUri="$(jq -r '.definition.notificationEndpointUri' <<< "$config")" \
        devopsServicePrincipalGroupPrincipalId="$(jq -r '.definition.devopsEntraGroupObjectId' <<< "$config")" \
        keyVaultDevopsServicePrincipalGroupPrincipalId="$(jq -r '.definition.keyvaultUserGroupObjectId' <<< "$config")"
)
echo "[✅] Deployment of the Service Catalog offer definition completed."

echo "[ℹ️] Starting deployment from Service Catalog offer definition..."
managedAppParameters="./managedapp.parameters.json"

jq '
    {
        "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
        contentVersion: "1.0.0.0",
        parameters: {
            analytics: { 
                value: {
                    useExistingCoManagedResourceGroup: .ama.analytics.useExistingCoManagedResourceGroup,
                    existingCoManagedResourceGroupName: .ama.analytics.existingCoManagedResourceGroupName,
                    useExistingSynapse: .ama.analytics.useExistingSynapse,
                    existingSynapseWorkspaceResourceId: .ama.analytics.existingSynapseWorkspaceResourceId,
                    useExistingPurview: .ama.analytics.useExistingPurview,
                    purviewName: .ama.analytics.purviewName,
                    purviewResourceId: .ama.analytics.purviewResourceId,
                    synapseSqlAdminGroupObjectId: .ama.analytics.synapseSqlAdminGroupObjectId
                } 
            },
            location: { value: .global.azureLocation },
            principalClientId: { value: .ama.subOwner.identity.clientId },
            principalObjectId: { value: .ama.subOwner.identity.objectId },
            principalSecret: { value: .ama.subOwner.identity.clientSecret },
            analyticsPrincipalClientId: { value: .ama.analytics.identity.clientId },
            analyticsPrincipalObjectId: { value: .ama.analytics.identity.objectId },
            analyticsPrincipalSecret: { value: .ama.analytics.identity.clientSecret },
            customerTenantId: { value: .ama.tenantId },
            crossTenant: { value: .ama.crossTenant },
            applicationResourceName: { value: .ama.name },
        } 
    }' <<< "$config" > "$managedAppParameters"

jq '.parameters.applicationDefinitionResourceId = { "value": "'"$(jq -r '.properties.outputResources[0].id' <<< "$definitionDeployment")"'" }' "$managedAppParameters" > tmp && mv tmp "$managedAppParameters"
echo "[ℹ️] Using the following parameters for the deployment from Service Catalog offer from a definition:"
cat "$managedAppParameters"

amaDeployment=$(az deployment group create \
    --resource-group "$(jq -r '.ama.resourceGroupName' <<< "$config")" \
    --template-file ./.templates/deploy-from-service-catalog-definition.bicep \
    --parameters "$managedAppParameters"
)
echo "[✅] Deployment from Service Catalog offer definition completed."

echo "[ℹ️] Using Azure account with permissions on the sub provided by the customer"
customerClientId=$(jq -r '.ama.subOwner.identity.clientId' <<< "$config")
customerClientSecret=$(jq -r '.ama.subOwner.identity.clientSecret' <<< "$config")
customerTenantId=$(jq -r '.ama.tenantId' <<< "$config")
az login --service-principal -u "$customerClientId" -p "$customerClientSecret" --tenant "$customerTenantId"

coManagedParameters="./co-managed.parameters.json"
managedAppId=$(echo "$amaDeployment" | jq -r '.properties.outputResources[0].id')
managedApp=$(az managedapp show --id "$managedAppId")

jq '
    {
        "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
        contentVersion: "1.0.0.0",
        parameters: {
            location: { value: .parameters.location.value },
            shortLocation: { value: .outputs.shortLocation.value },
            resourceSuffix: { value: .outputs.resourceSuffix.value },
            analyticsUseExistingCoManagedResourceGroup: { value: .outputs.analytics.value.useExistingCoManagedResourceGroup },
            analyticsExistingCoManagedResourceGroupName: { value: .outputs.analytics.value.existingCoManagedResourceGroupName },
            useExistingSynapse: { value: .outputs.analytics.value.useExistingSynapse },
            synapseWorkspaceResourceId: { value: .outputs.analytics.value.existingSynapseWorkspaceResourceId },
            analyticsUseExistingPurview: { value: .outputs.analytics.value.useExistingPurview },
            analyticsPurviewResourceId: { value: .outputs.analytics.value.purviewResourceId },
            analyticsSynapseSqlAdminGroupObjectId: { value: .outputs.analytics.value.synapseSqlAdminGroupObjectId },
            foundationLogAnalyticsName: { value: .outputs.foundationLogAnalyticsName.value },
            analyticsFunctionAppName: { value: .outputs.analyticsFunctionAppName.value },
            analyticsDataShareName: { value: .outputs.analyticsDataShareName.value },
            offerTier: { value: .outputs.offerTier.value },
            environment: { value: .parameters.environment.value },
        }
    }
' <<< "$managedApp" > "$coManagedParameters"

managedRgId=$(jq -r '.managedResourceGroupId' <<< "$managedApp")
managedRgName=$(basename "$managedRgId")

analyticsPrincipalObjectId=$(jq -r '.ama.analytics.identity.objectId' <<< "$config")
useExistingPurview=$(jq -r '.ama.analytics.useExistingPurview' <<< "$config")

analyticsPurviewPrincipalId=""
if [ "$useExistingPurview" = "true" ] ; then
    purviewResourceId=$(jq -r '.ama.analytics.purviewResourceId' <<< "$config")
    analyticsPurviewPrincipalId=$(az resource show --id "$purviewResourceId" -o tsv --query 'identity.principalId')
else
    analyticsPurviewPrincipalId=$(jq -r '.ama.analytics.identity.objectId' <<< "$config")
fi

jq '.parameters.managedResourceGroupName = { "value": "'"$managedRgName"'" }' "$coManagedParameters" > tmp && mv tmp "$coManagedParameters"
jq '.parameters.analyticsPurviewPrincipalId = { "value": "'"$analyticsPurviewPrincipalId"'" }' "$coManagedParameters" > tmp && mv tmp "$coManagedParameters"
jq '.parameters.customerClientId = { "value": "'"$customerClientId"'" }' "$coManagedParameters" > tmp && mv tmp "$coManagedParameters"
jq '.parameters.customerClientSecret = { "value": "'"$customerClientSecret"'" }' "$coManagedParameters" > tmp && mv tmp "$coManagedParameters"
jq '.parameters.analyticsPrincipalObjectId = { "value": "'"$analyticsPrincipalObjectId"'" }' "$coManagedParameters" > tmp && mv tmp "$coManagedParameters"

echo "[ℹ️] Using the following parameters for the deployment of the Co-Managed scope:"
cat "$coManagedParameters"

echo "[ℹ️] Starting deployment of the Co-Managed scope..."
coManagedDeployment=$(az deployment sub create -n "eds-co-managed" \
    --location "$(jq -r '.global.azureLocation' <<< "$config")" \
    --template-file ../infra/main-co-managed.bicep \
    --parameters "$coManagedParameters"
)

echo "$coManagedDeployment"

purviewResourceName=$(echo "$coManagedDeployment" | jq -r '.properties.outputs.analyticsPurviewResourceName.value')
echo "$purviewResourceName"

echo "[✅] Deployment of the Co-Managed scope completed."

echo "[ℹ️] Building parameters of the Post-Deployment-Managed scope..."
postDeploymentParameters="./post-deployment-managed.parameters.json"
jq '
    {
        "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
        contentVersion: "1.0.0.0",
        parameters: {
            analyticsSynapseWorkspaceResourceId: { value: .properties.outputs.analyticsSynapseWorkspaceResourceId.value },
            analyticsCoManagedServiceProviderDatalakeResourceId: { value: .properties.outputs.analyticsServiceProviderDatalakeResourceId.value },
            analyticsCoManagedResourceGroupName: { value: .properties.outputs.analyticsCoManagedResourceGroupName.value },
        }
    }
' <<< "$coManagedDeployment" > "$postDeploymentParameters"

jq '.parameters.shortLocation = { value: "'"$(jq -r '.outputs.shortLocation.value' <<< "$managedApp")"'" }' "$postDeploymentParameters" > tmp && mv tmp "$postDeploymentParameters"
jq '.parameters.resourceSuffix = { value: "'"$(jq -r '.outputs.resourceSuffix.value' <<< "$managedApp")"'" }' "$postDeploymentParameters" > tmp && mv tmp "$postDeploymentParameters"

jq '.parameters.location = { value: "'"$(jq -r '.global.azureLocation' <<< "$config")"'" }' "$postDeploymentParameters" > tmp && mv tmp "$postDeploymentParameters"
jq '.parameters.useExistingSynapse = { value: '"$(jq -r '.ama.analytics.useExistingSynapse' <<< "$config")"' }' "$postDeploymentParameters" > tmp && mv tmp "$postDeploymentParameters"
jq '.parameters.environment = { value: "'"$(jq -r '.ama.environment' <<< "$config")"'" }' "$postDeploymentParameters" > tmp && mv tmp "$postDeploymentParameters"
jq '.parameters.customerClientId = { value: "'"$(jq -r '.ama.subOwner.identity.clientId' <<< "$config")"'" }' "$postDeploymentParameters" > tmp && mv tmp "$postDeploymentParameters"
jq '.parameters.customerClientSecret = { value: "'"$(jq -r '.ama.subOwner.identity.clientSecret' <<< "$config")"'" }' "$postDeploymentParameters" > tmp && mv tmp "$postDeploymentParameters"
jq '.parameters.customerTenantId = { value: "'"$(jq -r '.ama.tenantId' <<< "$config")"'" }' "$postDeploymentParameters" > tmp && mv tmp "$postDeploymentParameters"

echo "[ℹ️] Using an identity having access to the managed resource group..."
az login
subscriptionId=$(jq -r '.global.subscriptionId' <<< "$config")
az account set -s "$subscriptionId"

echo "[ℹ️] Starting deployment of the Post-Deployment-Managed scope..."
az deployment group create -n "eds-post-deployment" \
    --resource-group "$managedRgName" \
    --template-file ../infra/main-post-deployment.bicep \
    --parameters "$postDeploymentParameters"
echo "[✅] Deployment of the Post-Deployment-Managed scope completed."


echo "[ℹ️] Starting permission assignment for the Data Services Data Planes..."
#####################################################
# Purview

 useExistingPurview="$(jq -r '.ama.analytics.useExistingPurview' <<< "$config")"
 if [ "$useExistingPurview" = "true" ] ; then
      purviewResourceName=$(jq -r '.ama.analytics.purviewName' <<< "$config")
 fi

# Retrieve signed-in-user
owner_object_id=$(az ad signed-in-user show --output json | jq -r '.id')
co_managed_resource_group_name=$(jq -r '.ama.analytics.existingCoManagedResourceGroupName' <<< "$config")

# Add signed-in user to root collection
az purview account add-root-collection-admin --account-name "$purviewResourceName" --resource-group "$co_managed_resource_group_name" --object-id "$owner_object_id"

# Allow Reader to current subscription for analyticsPrincipalObjectId
az role assignment create --role "Reader" --assignee "${analyticsPrincipalObjectId}" --scope "/subscriptions/${subscriptionId}" -o none

# Grant SP Collection Administration, Data Source Administrator, Data Reader and Data Curator in Purview
echo "Grant SP Collection Administration, Data Source Administrator and Data Curator in Purview"
purview_access_token=$(az account get-access-token --resource https://purview.azure.net/ --query accessToken --output tsv)

for metadatarole in purviewmetadatarole_builtin_collection-administrator purviewmetadatarole_builtin_data-source-administrator purviewmetadatarole_builtin_data-curator purviewmetadatarole_builtin_purview-reader; do  
    body1=$(curl -s -H "Authorization: Bearer $purview_access_token" "https://${purviewResourceName}.purview.azure.com/policystore/collections/${purviewResourceName}/metadataPolicy?api-version=2021-07-01")
    metadata_policy_id=$(echo "$body1" | jq -r '.id')
    purviewMetadataPolicyUri="https://${purviewResourceName}.purview.azure.com/policystore/metadataPolicies/${metadata_policy_id}?api-version=2021-07-01"

    body2=$(echo "$body1" | 
        jq --arg perm "${metadatarole}" --arg objectid "${analyticsPrincipalObjectId}" '(.properties.attributeRules[] | 
            select(.id | contains($perm)) | 
                .dnfCondition[][] | 
                    select(.attributeName == "principal.microsoft.id") | 
                        .attributeValueIncludedIn) += [$objectid]')

    curl -H "Authorization: Bearer $purview_access_token" -H "Content-Type: application/json" -d "$body2" -X PUT -i -s "${purviewMetadataPolicyUri}" > /dev/null
done



