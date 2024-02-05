####################################################################################################################################################
### From the python terminal run the following: 
######################################pip install -r <path where the file is> requirements.txt######################################
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

#### Create Functions to Add permissions.

######################################################
###Get the crendentials to connect
######################################################
def get_credential_auth(tenant_id, client_id, client_secret):
    # azure.identity.aio
    credential = ClientSecretCredential(
        tenant_id=tenant_id,
        client_id=client_id,
        client_secret=client_secret)
    return credential

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

    async with aiohttp.ClientSession() as session:
        async with session.post(token_url, data=token_data) as response:
            token_response = await response.json()
            access_token = token_response.get('access_token')
    return access_token


######################################################
###Add permissions accordingly
######################################################

async def AddPermission(credential, principal_id, resource_id, app_role_id):

    # scope
    scopes = ['https://graph.microsoft.com/.default']

    ## df021288-bdef-4463-88db-98f22de89214 (id) - User.Read.All 
    graph_client = GraphServiceClient(credential, scopes) # type: ignore

    #Conversion not necessary
    #uuid_principal_id = UUID(principal_id)
    #uuid_resource_id = UUID(resource_id)
    #uuid_app_role_id = UUID(app_role_id)

    request_body = AppRoleAssignment(
        principal_id=principal_id,
        resource_id=resource_id,
        app_role_id=app_role_id,
    )

    result = await graph_client.service_principals.by_service_principal_id(principal_id).app_role_assigned_to.post(request_body)
    ## service principal id from the Enterprise applications - (Object ID)
    print(result)

######################################################
##get the list filtered
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

######################################################
## get the list with the token
######################################################
async def main_token(tenant_id, client_id, client_secret):
    endpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals'
    access_token = await get_credential_token(tenant_id, client_id, client_secret)
    result = await get_service_principals_token(access_token, endpoint)
    print(result)

######################################################
## Add permissions
######################################################
async def add_only_permission(credential, principal_id, resource_id):
    
    # Define permissions and their corresponding app_role_ids
    permissions = {
        "Applications.Read.All": "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30",
        "Group.Read.All": "5b567255-7703-4780-807c-7be8301ae99b",
        "User.Read.All": "df021288-bdef-4463-88db-98f22de89214",
        "GroupMember.Read.All": "98830695-27a2-44f7-8c18-0c3ebc9698f6"
    }
    
    for permission, app_role_id in permissions.items():
        await AddPermission(credential, principal_id, resource_id, app_role_id)



######################################################
## Return user with high permission from the file 'provision.config.template.json'
##File should be local in the same folder as this script
##strucure expected: "ama" -> "generalAdmin" -> "identity" -> 
######################################################
import json

def get_json_info(filename, generalAdmin = 'True'):
    try:
        with open(filename, 'r') as f:
            data = json.load(f)

            tenant_id = data.get('ama', {}).get('tenantId', {})
            print (tenant_id)
        if generalAdmin == 'True': 
            # Access the client ID for generalAdmin
            ga_client_id = data.get('ama', {}).get('generalAdmin', {}).get('identity', {})
            
            if ga_client_id:
                clientId = ga_client_id.get('clientId')
                objectId = ga_client_id.get('objectId')
                clientSecret = ga_client_id.get('clientSecret')
                return clientId,  clientSecret, tenant_id ##,objectId
        if generalAdmin == 'False':
             # Access the client ID for user to receive permissions
            ga_client_id = data.get('ama', {}).get('analytics', {}).get('identity', {})
            
            if ga_client_id:
                #clientId = ga_client_id.get('clientId')
                objectId = ga_client_id.get('objectId')
                #clientSecret = ga_client_id.get('clientSecret')
                return objectId, tenant_id
        else:
            raise ValueError("Client information was not found in the JSON file.")

    except Exception as e:
        return None,  str(e)




##########################################################
### Executing:
##########################################################
    

###Flow


##user with high permissions ## get it from the file.
filename = 'provision.config.template.json'
client_id,  client_secret, tenant_id = get_json_info(filename, generalAdmin = 'True')
principal_id, tenant_id = get_json_info(filename, generalAdmin = 'False')


##getting Microsoft Graph resource
resource_id =asyncio.run(main_token(tenant_id, client_id, client_secret))
##Credentials -> user with high permission
credential = get_credential_auth(tenant_id, client_id, client_secret)


##adding only the permissions needed
asyncio.run(add_only_permission(credential, principal_id, resource_id))

##example
#app_role_id = "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"
#asyncio.run(AddPermission(credential, principal_id, resource_id, app_role_id))


#•	Applications.Read.All - 9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30
#•	Group.Read.All - 5b567255-7703-4780-807c-7be8301ae99b
#•	User.Read.All - df021288-bdef-4463-88db-98f22de89214
#•	GroupMember.Read.All -  98830695-27a2-44f7-8c18-0c3ebc9698f6