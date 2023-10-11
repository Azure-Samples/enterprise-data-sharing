#!/bin/bash
set -euo pipefail

read -r -p "What is the resource group name to which the managed app should be deployed to: " RESOURCE_GROUP_NAME
read -r -p "Which parameters file should be used: " PARAMETERS_FILE_PATH

echo "[ℹ️] Starting deployment from Service Catalog offer definition..."
az deployment group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file ./.templates/deploy-from-service-catalog-definition.bicep \
    --parameters "$PARAMETERS_FILE_PATH"
echo "[✅] Deployment from Service Catalog offer definition completed."
