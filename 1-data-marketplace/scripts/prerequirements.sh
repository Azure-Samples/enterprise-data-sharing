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

if [ -f ./provision.config.json ]
then
    config=$(jq -r . provision.config.json)
else 
    echo "No provision.config.json file found"
    exit 1
fi

az login
azureSubscriptionId=$(jq -r '.global.subscriptionId' <<< "$config")
az account set --subscription "$azureSubscriptionId"

# Create resource group for definition
resource_group_name="$(jq -r '.definition.resourceGroupName' <<< "$config")"
echo "Creating resource group: $resource_group_name"
az group create --name "$resource_group_name" --location "$(jq -r '.global.azureLocation' <<< "$config")"

# Create resource group for maneged app
resource_group_name="$(jq -r '.ama.resourceGroupName' <<< "$config")"
echo "Creating resource group: $resource_group_name"
az group create --name "$resource_group_name" --location "$(jq -r '.global.azureLocation' <<< "$config")"

# Create resource group for co-managed resource group
resource_group_name=$(jq -r '.ama.analytics.existingCoManagedResourceGroupName' <<< "$config")
echo "Creating resource group: $resource_group_name"
az group create --name "$resource_group_name" --location "$(jq -r '.global.azureLocation' <<< "$config")"

# By default retrieve signed-in-user
# The signed-in user will also receive all KeyVault persmissions
owner_object_id=$(az ad signed-in-user show --output json | jq -r '.id')

# Create Entra groups
echo "Creating AD Group for DevOps: devopsEntraGroup"
ad_group_id_devops=$(az ad group create --display-name devopsEntraGroup --mail-nickname devopsEntraGroup --output json | jq -r '.id')
az ad group member add --group devopsEntraGroup --member-id "$owner_object_id"
echo "owner_object_id: $owner_object_id"

echo "Creating AD Group for KeyVault: keyvaultUserGroup"
ad_group_id_kv=$(az ad group create --display-name keyvaultUserGroup --mail-nickname keyvaultUserGroup --output json | jq -r '.id')
az ad group member add --group keyvaultUserGroup --member-id "$owner_object_id"
echo "ad_group_id_kv: $ad_group_id_kv"

echo "Creating AD Group for Synapse: synapseSqlAdminGroup"
ad_group_id_synapse=$(az ad group create --display-name synapseSqlAdminGroup --mail-nickname synapseSqlAdminGroup --output json | jq -r '.id')
echo "ad_group_id_synapse: $ad_group_id_synapse"

# Replace Entra IDs in config file
ad_group_id_devops=$(az ad group list --display-name devopsEntraGroup --query "[].id" --output tsv)
echo "Get AAD Group for DevOps ID: ${ad_group_id_devops}"

until [ -n "${ad_group_id_devops}" ]
    do
        echo "waiting for the devops aad group to be created..."
        sleep 10
    done
tmp=$(mktemp)
jq --arg a "${ad_group_id_devops}" '.definition.devopsEntraGroupObjectId = $a' ./provision.config.json > "$tmp" && mv "$tmp" ./provision.config.json

ad_group_id_kv=$(az ad group list --display-name keyvaultUserGroup --query "[].id" --output tsv)
echo "Get AAD Group for KeyVault ID: ${ad_group_id_kv}"
until [ -n "${ad_group_id_kv}" ]
    do
        echo "waiting for the keyvault aad group to be created..."
        sleep 10
    done
tmp1=$(mktemp)
jq --arg a "${ad_group_id_kv}" '.definition.keyvaultUserGroupObjectId = $a' ./provision.config.json > "$tmp1" && mv "$tmp1" ./provision.config.json

ad_group_id_synapse=$(az ad group list --display-name synapseSqlAdminGroup --query "[].id" --output tsv)
echo "Get AAD Groupfor Synapse ID: ${ad_group_id_synapse}"
until [ -n "${ad_group_id_synapse}" ]
    do
        echo "waiting for the synapse aad group to be created..."
        sleep 10
    done
tmp2=$(mktemp)
jq --arg a "${ad_group_id_synapse}" '.ama.analytics.synapseSqlAdminGroupObjectId = $a' ./provision.config.json > "$tmp2" && mv "$tmp2" ./provision.config.json

######################################################
# Create SP for Analytics Package
echo "Creating Service Principal to run the Analytics workloads"
 sp_app_name="analytics-sp"
 sp_app_out=$(az ad sp create-for-rbac \
     --role Reader \
     --scopes "/subscriptions/$azureSubscriptionId" \
     --name "$sp_app_name" \
     --output json)
 sp_app_id=$(echo "$sp_app_out" | jq -r '.appId')
 sp_app_pass=$(echo "$sp_app_out" | jq -r '.password')
 sp_app_tenant=$(echo "$sp_app_out" | jq -r '.tenant')

 sp_app_object_id=$(az ad sp show --id "$sp_app_id" --query id --out tsv)
 echo "sp_app_id: $sp_app_id"
 echo "sp_app_pass: $sp_app_pass"
 echo "sp_app_tenant: $sp_app_tenant"
 echo "sp_app_object_id: $sp_app_object_id"

tmp=$(mktemp)
jq --arg a "${sp_app_id}" '.ama.analytics.identity.clientId = $a' ./provision.config.json > "$tmp" && mv "$tmp" ./provision.config.json
tmp1=$(mktemp)
jq --arg a "${sp_app_object_id}" '.ama.analytics.identity.objectId = $a' ./provision.config.json > "$tmp1" && mv "$tmp1" ./provision.config.json
tmp2=$(mktemp)
jq --arg a "${sp_app_pass}" '.ama.analytics.identity.clientSecret = $a' ./provision.config.json > "$tmp2" && mv "$tmp2" ./provision.config.json

az ad group member add --group synapseSqlAdminGroup --member-id "$sp_app_object_id"

######################################################
# Create SP for SubOwner configuration
echo "Creating Service Principal for SubOwner Configuration"
 sp_app_subowner="subowner-sp"
 sp_app_subowner_out=$(az ad sp create-for-rbac \
     --role Owner \
     --scopes "/subscriptions/$azureSubscriptionId" \
     --name "$sp_app_subowner" \
     --output json)
 sp_app_subowner_id=$(echo "$sp_app_subowner_out" | jq -r '.appId')
 sp_app_subowner_pass=$(echo "$sp_app_subowner_out" | jq -r '.password')
 sp_app_subowner_tenant=$(echo "$sp_app_subowner_out" | jq -r '.tenant')

 sp_app_subowner_object_id=$(az ad sp show --id "$sp_app_subowner_id" --query id --out tsv)

 echo "sp_app_subowner_id: $sp_app_subowner_id"
 echo "sp_app_subowner_pass: $sp_app_subowner_pass"
 echo "sp_app_subowner_tenant: $sp_app_subowner_tenant"
 echo "sp_app_subowner_object_id: $sp_app_subowner_object_id"

tmp=$(mktemp)
jq --arg a "${sp_app_subowner_id}" '.ama.subOwner.identity.clientId = $a' ./provision.config.json > "$tmp" && mv "$tmp" ./provision.config.json
tmp1=$(mktemp)
jq --arg a "${sp_app_subowner_object_id}" '.ama.subOwner.identity.objectId = $a' ./provision.config.json > "$tmp1" && mv "$tmp1" ./provision.config.json
tmp2=$(mktemp)
jq --arg a "${sp_app_subowner_pass}" '.ama.subOwner.identity.clientSecret = $a' ./provision.config.json > "$tmp2" && mv "$tmp2" ./provision.config.json

az ad group member add --group synapseSqlAdminGroup --member-id "$sp_app_subowner_object_id"