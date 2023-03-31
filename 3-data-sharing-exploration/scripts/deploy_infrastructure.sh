#!/bin/bash

# Access granted under MIT Open Source License: https://en.wikipedia.org/wiki/MIT_License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated 
# documentation files (the "Software"), to deal in the Software without restriction, including without limitation 
# the rights to use, copy, modify, merge, publish, distribute, sublicense, # and/or sell copies of the Software, 
# and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions 
# of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
# TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF 
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
# DEALINGS IN THE SOFTWARE.

#######################################################
# Deploys all necessary azure resources and stores
# configuration information in an .ENV file
#
# Prerequisites:
# - User is logged in to the azure cli
# - Correct Azure subscription is selected
#######################################################

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace # For debugging

. ./scripts/common.sh

###################
# REQUIRED ENV VARIABLES:
#
# PROJECT
# DEPLOYMENT_ID
# AZURE_LOCATION
# AZURE_SUBSCRIPTION_ID


#####################
# DEPLOY ARM TEMPLATE

# Set account to where ARM template will be deployed to
echo "Deploying to Subscription: $AZURE_SUBSCRIPTION_ID"
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# Create resource group
resource_group_name="$PROJECT-$DEPLOYMENT_ID-rg"
echo "Creating resource group: $resource_group_name"
az group create --name "$resource_group_name" --location "$AZURE_LOCATION"

# By default retrieve signed-in-user
# The signed-in user will also receive all KeyVault persmissions
owner_object_id=$(az ad signed-in-user show --output json | jq -r '.id')

# Validate arm template
echo "Validating deployment"
arm_output=$(az deployment group validate \
    --resource-group "$resource_group_name" \
    --template-file "./infrastructure/main.bicep" \
    --parameters project="${PROJECT}" deployment_id="${DEPLOYMENT_ID}" keyvault_owner_object_id="${owner_object_id}"  \
    --output json)

# Deploy arm template
echo "Deploying resources into $resource_group_name"
arm_output=$(az deployment group create \
    --resource-group "$resource_group_name" \
    --template-file "./infrastructure/main.bicep" \
    --parameters project="${PROJECT}" deployment_id="${DEPLOYMENT_ID}" keyvault_owner_object_id="${owner_object_id}" \
    --output json)

if [[ -z $arm_output ]]; then
    echo >&2 "ARM deployment failed."
    exit 1
fi

##########################################
# Upload Sample Data v1 and v2

# Retrive account and key
azure_storage_account=$(echo "$arm_output" | jq -r '.properties.outputs.storage_account_name.value')
azure_storage_key=$(az storage account keys list \
    --account-name "$azure_storage_account" \
    --resource-group "$resource_group_name" \
    --output json | jq -r '.[0].value')


kv_name=$(echo "$arm_output" | jq -r '.properties.outputs.keyvault_name.value')
az keyvault secret set --vault-name "$kv_name" --name "datalakeKey" --value "$azure_storage_key" -o none

echo "Uploading Sample Data v1"
az storage blob upload-batch --account-name "$azure_storage_account" --account-key "$azure_storage_key" \
    --destination 'adventureworkslt/v1' --source 'sample_data/v1' --overwrite

echo "Uploading Sample Data v2"
az storage blob upload-batch --account-name "$azure_storage_account" --account-key "$azure_storage_key" \
    --destination 'adventureworkslt/v2' --source 'sample_data/v2' --overwrite

echo "Uploading Metadata"
az storage blob upload-batch --account-name "$azure_storage_account" --account-key "$azure_storage_key" \
    --destination 'adventureworkslt/_meta' --source 'sample_data/_meta' --overwrite

####################
# SYNAPSE ANALYTICS

echo "Retrieving Synapse Analytics information from the deployment."
synapseworkspace_name=$(echo "$arm_output" | jq -r '.properties.outputs.synapseworskspace_name.value')
echo "$synapseworkspace_name"
synapse_serverless_endpoint=$(az synapse workspace show \
    --name "$synapseworkspace_name" \
    --resource-group "$resource_group_name" \
    --output json |
    jq -r '.connectivityEndpoints | .sqlOnDemand')

synapse_sparkpool_name=$(echo "$arm_output" | jq -r '.properties.outputs.synapse_output_spark_pool_name.value')
# Save Synapse info in KV
az keyvault secret set --vault-name "$kv_name" --name "synapseWorkspaceName" --value "$synapseworkspace_name" -o none
sleep 20

# Grant Synapse Administrator to the deployment owner
assign_synapse_role_if_not_exists "$synapseworkspace_name" "Synapse Administrator" "$owner_object_id"
assign_synapse_role_if_not_exists "$synapseworkspace_name" "Synapse Contributor" "$synapseworkspace_name"

###################
# DEPLOY ALL FOR EACH SEC GROUP
security_groups=""
declare -i i=0

for SEC_LEVEL in LOW MED HIG; do  
    echo "Creating AAD Group:AADGR${PROJECT}${DEPLOYMENT_ID}${SEC_LEVEL}"
    aad_group_name="AADGR${PROJECT}${DEPLOYMENT_ID}${SEC_LEVEL}"
    aad_group_output=$(az ad group create --display-name "${aad_group_name}" --mail-nickname "${aad_group_name}" --output json)
    aad_group_id=$(echo $aad_group_output | jq -r '.id')

    ####################
    # CLS
    # Get AAD Group ObjectID
    aadGroupObjectId=$(az ad group list --filter "(displayName eq 'AADGR${PROJECT}${DEPLOYMENT_ID}${SEC_LEVEL}')" --query "[].id" --output tsv)
    echo "Get AAD Group id: ${aadGroupObjectId}"
    until [ -n "${aadGroupObjectId}" ]
        do
            echo "waiting for the aad group to be created..."
            sleep 10
        done
    
    echo "Adding the AAD Group Object Id to the KeyVault"
    az keyvault secret set --vault-name "$kv_name" --name "OBJID-${aad_group_name}" --value "${aadGroupObjectId}" -o none

    #################
    # RBAC - Synapse 
    # Allow Synapse Reader access to the AADGroup
    assign_synapse_role_if_not_exists "$synapseworkspace_name" "Synapse User" "$aadGroupObjectId"

    # Add the owner of the deployment to the AAD Group, if you have permissions to do it (otherwise you will need to request to the AAD admin and comment this line)
    echo "Adding members to AAD Group:AADGR${PROJECT}${DEPLOYMENT_ID}${SEC_LEVEL}"
    az ad group member add --group "AADGR${PROJECT}${DEPLOYMENT_ID}${SEC_LEVEL}" --member-id $owner_object_id -o none

    # Allow Contributor to the AAD Group on Synapse workspace
    az role assignment create --role "Contributor" --assignee-object-id "${aadGroupObjectId}" --assignee-principal-type "Group" --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${resource_group_name}/providers/Microsoft.Synapse/workspaces/${synapseworkspace_name}" -o none

    # Allow Contributor to the AAD Group on Synapse workspace
    echo "Giving ACL permission on the adventureworkslt container for the AAD Group"
    az storage fs access set --acl "group:${aadGroupObjectId}:rwx" -p "/" -f "adventureworkslt" --account-name "$azure_storage_account" --account-key "$azure_storage_key" -o none

    # Add SEC GROUP NAMES from deployment to Security File
    echo "Add Security Group Names from deployment to Security File"
    security_group="${aad_group_name}"
    if [ "$security_groups" == "" ]; then security_groups=\"${security_group}\" ; else security_groups=${security_groups},\"${security_group}\" ; fi
    tmp=$(mktemp)
    jqfilter=".rules[${i}].security_group=\"${security_group}\""
    jq "$jqfilter" ./data_security_file/data_security_file.json > "$tmp" && mv "$tmp" ./data_security_file/data_security_file.json
    echo "${security_groups}"
    i+=1
done

tmp2=$(mktemp)
jqfilter=".security_groups = [${security_groups}]"
jq "$jqfilter" ./data_security_file/data_security_file.json > "$tmp2" && mv "$tmp2" ./data_security_file/data_security_file.json

######################################################
# Adding Security File to KY
echo "Add Security File content to KeyVault"
az keyvault secret set --vault-name "$kv_name" --name "securityFile" --file "./data_security_file/data_security_file.json" -o none

######################################################
# Deploy SP to be used by the external Python APP
echo "Creating Service Principal to run python code"
 sp_app_name="${PROJECT}-${DEPLOYMENT_ID}-sp"
 sp_app_out=$(az ad sp create-for-rbac \
     --role Contributor \
     --scopes "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$resource_group_name/providers/Microsoft.Synapse/workspaces/$synapseworkspace_name" \
     --name "$sp_app_name" \
     --output json)
 sp_app_id=$(echo "$sp_app_out" | jq -r '.appId')
 sp_app_pass=$(echo "$sp_app_out" | jq -r '.password')
 sp_app_tenant=$(echo "$sp_app_out" | jq -r '.tenant')

 sp_app_object_id=$(az ad sp show --id "$sp_app_id" --query id --out tsv)

# Save SP credentials in Keyvault
 az keyvault secret set --vault-name "$kv_name" --name "spAppName" --value "$sp_app_name" -o none
 az keyvault secret set --vault-name "$kv_name" --name "spAppId" --value "$sp_app_id" -o none
 az keyvault secret set --vault-name "$kv_name" --name "spAppPass" --value "$sp_app_pass" -o none
 az keyvault secret set --vault-name "$kv_name" --name "spAppTenantId" --value "$sp_app_tenant" -o none
 az keyvault secret set --vault-name "$kv_name" --name "spObjectId" --value "$sp_app_object_id" -o none

wait_service_principal_creation "$sp_app_id"

# Grant SP Contributor to the Synapse Workspace
echo "Grant SP Contributor to the Synapse Workspace"
az role assignment create --role "Contributor" --assignee-object-id "${sp_app_id}" --assignee-principal-type "ServicePrincipal" --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${resource_group_name}/providers/Microsoft.Synapse/workspaces/${synapseworkspace_name}" -o none

# Grant SP Stg.Blob Data Owner in the Data lake
echo "Grant SP Stg.Blob Data Owner in the Data lake"
az role assignment create --role "Storage Blob Data Owner" --assignee-object-id "${sp_app_object_id}" --assignee-principal-type "ServicePrincipal" --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${resource_group_name}/providers/Microsoft.Storage/storageAccounts/${PROJECT}st1${DEPLOYMENT_ID}/blobServices/default/containers/adventureworkslt" -o none

# Grant SP Stg.Blob Data Reader in the Data lake
echo "Grant SP Stg.Blob Data Reader in the Storage Internal account of Synapse"
az role assignment create --role "Storage Blob Data Reader" --assignee-object-id "${sp_app_object_id}" --assignee-principal-type "ServicePrincipal" --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${resource_group_name}/providers/Microsoft.Storage/storageAccounts/${PROJECT}st2${DEPLOYMENT_ID}" -o none

# Grant SP Key Vault Secret Officer in KY resource
echo "Grant SP Key Vault Secret Officer in KY resource"
az role assignment create --role "Key Vault Secrets Officer" --assignee-object-id "${sp_app_object_id}" --assignee-principal-type "ServicePrincipal" --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${resource_group_name}/providers/Microsoft.KeyVault/vaults/${kv_name}" -o none

# Grant Signed In user Stg.Blob Data Owner in the Data Lake 
echo "Grant Signed In user Stg.Blob Data Owner in the Data Lake"
az role assignment create --role "Storage Blob Data Owner" --assignee-object-id "${owner_object_id}" --assignee-principal-type "User" --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${resource_group_name}/providers/Microsoft.Storage/storageAccounts/${PROJECT}st1${DEPLOYMENT_ID}" -o none

#################
# RBAC - Synapse 
# Allow SQL Administrator to the SP
assign_synapse_role_if_not_exists "$synapseworkspace_name" "Synapse SQL Administrator" "${sp_app_object_id}"
   

#####################################################
# Purview

# Allow Contributor to Purview Managed Identity on the  Synapse workspace
echo "Grant Contributor to Purview MSI on the  Synapse workspace"
purviewPrincipalId=$(az ad sp list --display-name "pview${PROJECT}${DEPLOYMENT_ID}" --query [*].appId --out tsv)
az role assignment create --role "Reader" --assignee "${purviewPrincipalId}" --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${resource_group_name}/providers/Microsoft.Synapse/workspaces/${synapseworkspace_name}" -o none

# Grant SP Collection Administration, Data Source Administrator and Data Curator in Purview
echo "Grant SP Collection Administration, Data Source Administrator and Data Curator in Purview"
purview_access_token=$(az account get-access-token --resource https://purview.azure.net/ --query accessToken --output tsv)

for metadatarole in purviewmetadatarole_builtin_collection-administrator purviewmetadatarole_builtin_data-source-administrator purviewmetadatarole_builtin_data-curator; do  
    body1=$(curl -s -H "Authorization: Bearer $purview_access_token" "https://pview${PROJECT}${DEPLOYMENT_ID}.purview.azure.com/policystore/collections/pview${PROJECT}${DEPLOYMENT_ID}/metadataPolicy?api-version=2021-07-01")
    metadata_policy_id=$(echo "$body1" | jq -r '.id')
    purviewMetadataPolicyUri="https://pview${PROJECT}${DEPLOYMENT_ID}.purview.azure.com/policystore/metadataPolicies/${metadata_policy_id}?api-version=2021-07-01"

    body2=$(echo "$body1" | 
        jq --arg perm "${metadatarole}" --arg objectid "${sp_app_object_id}" '(.properties.attributeRules[] | 
            select(.id | contains($perm)) | 
                .dnfCondition[][] | 
                    select(.attributeName == "principal.microsoft.id") | 
                        .attributeValueIncludedIn) += [$objectid]')

    curl -H "Authorization: Bearer $purview_access_token" -H "Content-Type: application/json" -d "$body2" -X PUT -i -s "${purviewMetadataPolicyUri}" > /dev/null
done

