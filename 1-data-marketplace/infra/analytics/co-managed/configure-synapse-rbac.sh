#! /bin/bash
set -euo pipefail

az login --service-principal -u $customerClientId -p "$customerClientSecret" -t $customerTenantId --output none
az account set -s $subscriptionId

removeFirewallRule() {
    echo "### Remove synapse rbac config deployment script firewall rule"
    az synapse workspace firewall-rule delete \
    --name "$1" \
    --workspace-name "$2" \
    --resource-group "$3" \
    --yes
}

hostIP=$(curl ifconfig.me)
firewallRuleName="allowRbacConfigDeploymentScript"

echo "### Add firewall rule $firewallRuleName"
az synapse workspace firewall-rule create \
--name "${firewallRuleName}" \
--workspace-name "${workspaceName}" \
--resource-group "${resourceGroupName}" \
--start-ip-address "${hostIP}" \
--end-ip-address "${hostIP}"

echo "### Check role assignment needed"
synapseAdminRoleAssignment=""
synapseAdminRoleAssignmentId=""
attempt=1
maxAttempts=10
while [ -z "${synapseAdminRoleAssignmentId}" ] && [ -z "${synapseAdminRoleAssignment}" ]
do
    echo "### checking admin role assignment existency (attempt: $attempt/$maxAttempts)"
    set +e
    synapseAdminRoleAssignment=$(az synapse role assignment list --workspace-name "${workspaceName}" \
            --assignee-object-id "${sqlAdminGroupObjectId}" \
            --role "6e4bf58a-b8e1-4cc3-bbf9-d73143322b78")
    if [ $? -eq 0 ]
    then
        echo "### role assignment found, parsing its id"
        echo $synapseAdminRoleAssignment
        synapseAdminRoleAssignmentId=$(jq '.[].id' <<< ${synapseAdminRoleAssignment})
        echo "### role assignment id: ${synapseAdminRoleAssignmentId}"
    fi
    set -e

    if [ $maxAttempts -eq $attempt ]
    then
        echo "### failed to fetch extisting role assignment"
        removeFirewallRule $firewallRuleName $workspaceName $resourceGroupName
        exit 1
    fi

    sleep 5
    attempt=$((attempt + 1))
done

echo "### Grant AAD group '${sqlAdminGroupObjectId}' Synapse Administrator role"
roleAssignment=""
attempt=1
maxAttempts=10
while [ -z "${synapseAdminRoleAssignmentId}" ] && [ -z "${roleAssignment}" ]
do
    set +e
    echo "### Trying to add role assignment (attempt: ${attempt}/${maxAttempts})"
    roleAssignment=$(az synapse role assignment create \
    --workspace-name ${workspaceName} \
    --assignee-object-id ${sqlAdminGroupObjectId} \
    --assignee-principal-type Group \
    --role "Synapse Administrator")
    set -e

    if [ $maxAttempts -eq $attempt ]
    then
        echo "### Failed to add role assignment after $maxAttempts attempts, failing"
        removeFirewallRule $firewallRuleName $workspaceName $resourceGroupName
        exit 1
    fi

    sleep 5
    attempt=$((attempt + 1))
done

removeFirewallRule $firewallRuleName $workspaceName $resourceGroupName
