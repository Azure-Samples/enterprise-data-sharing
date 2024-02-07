####################################################################################################################################################
### From the python terminal run the following: 
######################################pip install -r <PATH where the file is> requirements.txt######################################
                                                        ####OR####
######################################conda env create -f <PATH/requirementmsgraphpython.yml>######################################
####################################################################################################################################################

###Libraries:
import asyncio
from azure.identity import ClientSecretCredential
from uuid import UUID
from msgraph import GraphServiceClient
from msgraph.generated.models.app_role_assignment import AppRoleAssignment
from msgraph.generated.service_principals.service_principals_request_builder import ServicePrincipalsRequestBuilder
from msgraph.generated.models.service_principal_collection_response import ServicePrincipalCollectionResponse
import pandas as pd
import json
import aiohttp

######################################################
#### Create Functions to Add permissions.
#### - Credentials or Token
######################################################
######################################################
###Get the crendentials to connect
######################################################
def get_credential_auth(tenant_id, client_id, client_secret):
    
    try: 
    
        credential = ClientSecretCredential(
            tenant_id=tenant_id,
            client_id=client_id,
            client_secret=client_secret)
        return credential
    except Exception as e:
        print(f"An error occurred while creating the credential: {e}")
        return None
    

######################################################
##get the token. 
######################################################
async def get_credential_token(tenant_id, client_id, client_secret):
    resource = 'https://graph.microsoft.com'
    # Acquire token using MSAL
    authority = f'https://login.microsoftonline.com/{tenant_id}'
    token_url = f'{authority}/oauth2/v2.0/token'
    token_data = {
        'grant_type': 'client_credentials',
        'client_id': client_id,
        'client_secret': client_secret,
        'scope': f'{resource}/.default'
    }

    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(token_url, data=token_data) as response:
                token_response = await response.json()
                access_token = token_response.get('access_token')
        return access_token
    except aiohttp.ClientError as e:
       print(f"An error occurred: {e}")
       return None


######################################################
#### Create Functions to Add permissions.
#### - ADD Permission Function Async
######################################################
async def addpermission(credential, principal_id, resource_id, app_role_id):

    # scope
    scopes = ['https://graph.microsoft.com/.default']

    try:
        ## df021288-bdef-4463-88db-98f22de89214 (id) - User.Read.All 
        graph_client = GraphServiceClient(credential, scopes) # type: ignore


        request_body = AppRoleAssignment(
            principal_id=principal_id,
            resource_id=resource_id,
            app_role_id=app_role_id,
        )

        result = await graph_client.service_principals.by_service_principal_id(principal_id).app_role_assigned_to.post(request_body)
    except Exception as e:
        print(f"An error occurred: {e}")
        return None


######################################################
#### Create Functions to Add permissions.
#### - GET REsource ID from Microsoft Graph
######################################################

async def get_service_principals_token(access_token, endpoint):
    # Make request to Microsoft Graph API
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }

    query_parameters = {
        '$filter': "displayName eq 'Microsoft Graph'",
        '$select': 'id,displayName,appId,appRoles'
    }
    try: 
        async with aiohttp.ClientSession() as session:
            async with session.get(endpoint, headers=headers, params=query_parameters) as response:
                if response.status == 200:
                    result = await response.json()

                    service_principals = result['value']
                    filtered_service_principals = []
                    for item in service_principals:
                        if item['displayName'] == 'Microsoft Graph' or any(role['displayName'] in ['Applications.Read.All', 'Group.Read.All', 'User.Read.All', 'GroupMember.Read.All'] for role in item.get('appRoles', [])):
                            filtered_service_principals.append(item)
                    
                    # Extract necessary data for DataFrame
                    service_principals_data = []
                    for item in filtered_service_principals:
                        service_principal_data = {
                            'id': item['id'],
                            'displayName': item['displayName'],
                            'appId': item['appId'],
                            'appRoles': item['appRoles'] if 'appRoles' in item else None
                        }
                        service_principals_data.append(service_principal_data)

                    df = pd.DataFrame(service_principals_data)


                    return df['id'][0]
                else:
                    print(f'Error: {response.status}')
                    print(await response.text())
                    return None
    except aiohttp.ClientError as e:
         print(f"An error occurred while requesting the resource_id of Microsoft Graph: {e}")
         return None
##############################################################################
#### Bridge Between Token and Graph List
#### - Depending on the get_credential_token and get_service_principals_token
##############################################################################

async def main_bridge_token_resourceid(tenant_id, client_id, client_secret):
    try: 
        endpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals'
        access_token = await get_credential_token(tenant_id, client_id, client_secret)
        result = await get_service_principals_token(access_token, endpoint)
        return result
    except Exception as e:
        print(f"An error occurred between the token and the resourceid: {e}")
        return None
##############################################################################################################
## Add ONLY Necessary permissions - Those numnbers are documented as follows:
## doc: https://learn.microsoft.com/en-us/graph/migrate-azure-ad-graph-permissions-differences#application
### - It depends on the addpermission previsouly created.
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
            await addpermission(credential, principal_id, resource_id, app_role_id)
    except Exception as e:
        print(f"An error occurred while adding one of the following permissions Applications.Read.All,Group.Read.All,User.Read.All,GroupMember.Read.All): {e}")
        return None
    
###########################################################################################
## Return user with high permission from the file 'provision.config.template.json'
##File should be local in the same folder as this script
##strucure expected: "ama" -> "generalAdmin" -> "identity" -> Generaladmin=true
##strucure expected: "ama" -> "analytics" -> "identity" -> Generaladmin=False
###########################################################################################
def get_json_info(filename, generalAdmin = 'True'):
    try:
        with open(filename, 'r') as f:
            data = json.load(f)

            tenant_id = data.get('ama', {}).get('tenantId', {})
            
        if generalAdmin == 'True': 
            # Access the client ID for generalAdmin
            ga_client_id = data.get('ama', {}).get('generalAdmin', {}).get('identity', {})
            
            if ga_client_id:
                clientId = ga_client_id.get('clientId')
                objectId = ga_client_id.get('objectId')
                clientSecret = ga_client_id.get('clientSecret')
                return clientId,  clientSecret, tenant_id 
        if generalAdmin == 'False':
             # Access the client ID for user to receive permissions
            ga_client_id = data.get('ama', {}).get('analytics', {}).get('identity', {})
            
            if ga_client_id:
                objectId = ga_client_id.get('objectId')
                return objectId, tenant_id
        else:
            raise ValueError("Client information was not found in the JSON file.")

    except Exception as e:
        return None,  str(e)




##########################################################
### Executing:
##########################################################
###Flow


## 1 - Read Config File
filename = 'provision.config.template.json'
client_id,  client_secret, tenant_id = get_json_info(filename, generalAdmin = 'True')
principal_id, tenant_id = get_json_info(filename, generalAdmin = 'False')


### 2 - Get resource id and Credentials
resource_id =asyncio.run(main_bridge_token_resourceid(tenant_id, client_id, client_secret))
##Credentials -> user with high permission
credential = get_credential_auth(tenant_id, client_id, client_secret)


## 3 - adding only the permissions needed
asyncio.run(add_only_permission(credential, principal_id, resource_id))
