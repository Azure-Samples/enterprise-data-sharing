#!/bin/bash
set -euo pipefail

read -r -p "Enter notification endpoint URI: " NOTIFICATION_ENDPOINT_URI
read -r -p "Please provide an Entra ID group object id which will be owner of the managed resource groups: " DEVOPS_GROUP_OBJECT_ID
read -r -p "Please provide an Entra ID group object id which will be key vault user of the managed key vault: " DEVOPS_KV_USER_GROUP_OBJECT_ID
read -r -p "What kind of environment ? (tst/prd): " ENVIRONMENT
read -r -p "What is the resource group name to which the definition will be deployed to: " DEFINITION_RESOURCE_GROUP_NAME

if [[ "$ENVIRONMENT" != "tst" && "$ENVIRONMENT" != "prd" ]]; then
    echo "Invalid environment specified. Please specify either 'tst' or 'prd'."
    exit 1
fi

UUID_REGEX="^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$"
if ! [[ $(echo "$DEVOPS_GROUP_OBJECT_ID" | grep -E $UUID_REGEX) ]]; then
    echo "Invalid UUID format. Please provide a valid UUID."
    exit 1
fi

if ! [[ $(echo "$DEVOPS_GROUP_OBJECT_ID" | grep -E $UUID_REGEX) ]]; then
    echo "Invalid UUID format. Please provide a valid UUID."
    exit 1
fi

if [[ -z "$NOTIFICATION_ENDPOINT_URI" ]]; then
    echo "Notification endpoint URI cannot be empty."
    exit 1
fi

if ! [[ "$NOTIFICATION_ENDPOINT_URI" =~ ^https?:// ]]; then
    echo "Invalid notification endpoint URI. Please provide a valid URI starting with 'http://' or 'https://'."
    exit 1
fi

if [[ -z "$DEFINITION_RESOURCE_GROUP_NAME" ]]; then
    echo "Resource group name cannot be empty."
    exit 1
fi

echo "[ℹ️] Generating ARM template from ./offers/service-catalog/infra/mainTemplate.bicep..."
az bicep build --file ./offers/service-catalog/infra/mainTemplate.bicep
echo "[✅] Generated ARM template from ./offers/service-catalog/infra/mainTemplate.bicep."

echo "[ℹ️] Starting deployment of the Service Catalog offer definition..."
az deployment group create \
    --resource-group "$DEFINITION_RESOURCE_GROUP_NAME" \
    --template-file ./offers/service-catalog/infra/main.bicep \
    --parameters notificationEndpointUri="$NOTIFICATION_ENDPOINT_URI" \
        devopsServicePrincipalGroupPrincipalId="$DEVOPS_GROUP_OBJECT_ID" \
        keyVaultDevopsServicePrincipalGroupPrincipalId="$DEVOPS_KV_USER_GROUP_OBJECT_ID" \
        environmentCode="$ENVIRONMENT"
echo "[✅] Deployment of the Service Catalog offer definition completed."
