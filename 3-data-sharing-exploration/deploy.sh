#!/bin/bash

sudo chmod +x "./scripts/deploy_infrastructure.sh"

. ./scripts/verify_prerequisites.sh

PROJECT=$PROJECT \
DEPLOYMENT_ID=$DEPLOYMENT_ID \
AZURE_LOCATION=$AZURE_LOCATION \
AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID \
bash -c "./scripts/deploy_infrastructure.sh"