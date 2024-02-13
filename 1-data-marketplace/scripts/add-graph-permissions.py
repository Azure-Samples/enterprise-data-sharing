####################################################################################################################################################
### From the python terminal run the following: 
######################################pip install -r <PATH where the file is> requirements.txt######################################
                                                        ####OR####
######################################conda env create -f <PATH/requirementmsgraphpython.yml>######################################
####################################################################################################################################################

###Libraries:
import asyncio
from azure.identity import ClientSecretCredential
from azure.identity import InteractiveBrowserCredential
from uuid import UUID
from msgraph import GraphServiceClient
from msgraph.generated.models.app_role_assignment import AppRoleAssignment
from msgraph.generated.service_principals.service_principals_request_builder import ServicePrincipalsRequestBuilder
from msgraph.generated.users.users_request_builder import UsersRequestBuilder
from msgraph.generated.models.service_principal_collection_response import ServicePrincipalCollectionResponse
import pandas as pd
import json
import aiohttp
import asyncio
import re




######################################################
#### Create Functions to Add permissions.

######################################################
#### Create Functions to Add permissions.
#### - GET REsource ID from Microsoft Graph
######################################################

async def list_interactive_main(credential):

    scopes = ['https://graph.microsoft.com/.default']
    
    # Initialize GraphServiceClient with the credential and scopes
    graph_client = GraphServiceClient(credential, scopes)
    
    # Build query parameters
    query_params = ServicePrincipalsRequestBuilder.ServicePrincipalsRequestBuilderGetQueryParameters(
        select=["id"],
        filter="displayName eq 'Microsoft Graph'", top=1
    )
    
    try:
        # Build request configuration
        request_configuration = ServicePrincipalsRequestBuilder.ServicePrincipalsRequestBuilderGetRequestConfiguration(
        query_parameters = query_params,
        )
        result = await graph_client.service_principals.get(request_configuration = request_configuration)

    except Exception as e:
        print(f"An error occurred while requesting the resource_id: {e}")
    
    ## From the string results extract only the resource_id
    result_str =str(result)
    match = re.search(r"id='(.+?)'", result_str)

    if match:
        resource_id = match.group(1)
    else:
        print("Resource_id is not found in the string")
    return resource_id
  
##############################################################################################################
## Add ONLY Necessary permissions - Those numnbers are documented as follows:
## doc: https://learn.microsoft.com/graph/migrate-azure-ad-graph-permissions-differences#application
##############################################################################################################
async def add_only_permission(credential, principal_id, resource_id):
    
    # Define permissions and their corresponding app_role_ids
    permissions = {
        "Applications.Read.All": "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30",
        "Group.Read.All": "5b567255-7703-4780-807c-7be8301ae99b",
        "User.Read.All": "df021288-bdef-4463-88db-98f22de89214",
        "GroupMember.Read.All": "98830695-27a2-44f7-8c18-0c3ebc9698f6"
    }
    try:

        for permission, app_role_id in permissions.items():
            #await addpermission(credential, principal_id, resource_id, app_role_id)
             # scope
            scopes = ['https://graph.microsoft.com/.default']

            try:
                ## df021288-bdef-4463-88db-98f22de89214 (id) - User.Read.All 
                graph_client = GraphServiceClient(credential, scopes) # type: ignore
                
                request_body = AppRoleAssignment(
                    principal_id=UUID(principal_id),
                    resource_id=UUID(resource_id),
                    app_role_id=UUID(app_role_id),
                )

                result = await graph_client.service_principals.by_service_principal_id(principal_id).app_role_assigned_to.post(request_body)
            except Exception as e:
                ##retry once in case this specific failure happens
                if "'NoneType' object has no attribute 'send'"  in str(e):
                    request_body = AppRoleAssignment(
                    principal_id=UUID(principal_id),
                    resource_id=UUID(resource_id),
                    app_role_id=UUID(app_role_id),
                    )

                    result = await graph_client.service_principals.by_service_principal_id(principal_id).app_role_assigned_to.post(request_body)
                else:
                    print(f"An error occurred: {e}")
    except Exception as e:
        print(f"An error occurred while adding one of the following permissions Applications.Read.All,Group.Read.All,User.Read.All,GroupMember.Read.All): {e}")
        return None
    
###########################################################################################
## Return user with high permission from the file 'provision.config.template.json'
##File should be local in the same folder as this script
##strucure expected: "ama" -> "analytics" -> "identity" -> "clientId", "objectId", "clientSecret"
    ##"clientId" --> Client ID from App registration
    ##"objectId" --> Enterprise App Objectid
###########################################################################################
def get_json_info(filename):
    try:
        with open(filename, 'r') as f:
            data = json.load(f)

            tenant_id = data.get('ama', {}).get('tenantId', {})
            
            # Access the client ID for user to receive permissions
            ga_client_id = data.get('ama', {}).get('analytics', {}).get('identity', {})
            
            if ga_client_id:
                clientId = ga_client_id.get('clientId')
                objectId = ga_client_id.get('objectId')
                clientSecret = ga_client_id.get('clientSecret')
                return clientId,objectId, clientSecret, tenant_id 
            else:
                raise ValueError("Client information was not found in the JSON file.")

    except Exception as e:
        return  str(e)




##########################################################
### Executing:
##########################################################
###Flow

######################################################
##user with admin permissions
######################################################
credential = InteractiveBrowserCredential()
scopes=['https://graph.microsoft.com/.default']
client = GraphServiceClient(credentials=credential, scopes=scopes,)


## 1 - Read Config File
filename = 'provision.config.template.json'
client_id,principal_id,clientSecret, tenant_id = get_json_info(filename)

## 2 - Get resource id and Credentials
resource_id =resource_id = asyncio.run(list_interactive_main(credential))


## 3 - adding only the permissions needed
asyncio.run(add_only_permission(credential, principal_id, resource_id))

