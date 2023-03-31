# Enterprise Data Sharing - Data Exploration

This sample is the third sample of the Enterprise Data Sharing series and it
implements the Data Exploration functionality. Data exploration happens after
the Data has been sold and shared by the Data provider to the Data Consumer in
the two previous stages: Data marketplace (or Internal Catalog) and the Data
sharing mechanism itself. This sample mimics an infra-structure deployed and
managed by the Data provider in the Data consumer subscription and is composed
of relevant Data Services: Azure Synapse, Microsoft Purview, Azure KeyVault and
Azure Data Lake. More importantly implements the iteration between those
services so that the data continuously shared is ready for consumption, in a
consistent state, well governed and secure.

The scope of the the sample is highlighted in red in the following architecture:

![Data Exploration](./images/eds-repo-data-exploration-zoom.drawio.svg)

The IaC deployment is included as part of the sample, plus the exploration
functionality in python that iterates with Microsoft Purview, Azure Synapse
Analytics, Azure KeyVault and Azure Data Lake Gen 2 as mentioned above as
represented below:

![Data Exploration Detail](./images/eds-repo-data-exploration.drawio.svg)

The present sample can be used individually or in combination with the other
parts of the series: 
 - eds-data-marketplace: that could replace the IaC module from the current
   sample.
 - eds-data-sharing-mechanism: fully automated core functionality of a [Data
  Share
  mechanism](https://github.com/Azure-Samples/modern-data-warehouse-dataops/tree/main/single_tech_samples/datashare)

Provisioning and orchestrating a Data Exploration infrastructure might not be
mandatory. Data consumers could bring their own analytics tools. However, in
cases where the Data consumers don't have the knowledge or willingness to manage
such infrastructure this could be a good option. Another case is where the Data
Provider offers pre-built logic that the Data consumer could take advantage
from.

# Contents

- [Enterprise Data Sharing - Data Exploration](#enterprise-data-sharing---data-exploration)
- [Contents](#contents)
  - [About the Sample](#about-the-sample)
  - [Deployment](#deployment)
  - [Data Transfer](#data-transfer)
  - [Initial Setup](#initial-setup)
  - [Data Ingestion](#data-ingestion)
  - [Data Catalog](#data-catalog)
  - [Data Security](#data-security)
    - [Data Security Basic](#data-security-basic)
    - [Data Security Advanced](#data-security-advanced)
  - [Running the Sample end-to-end](#running-the-sample-end-to-end)
    - [Pre-requirements without using Dev Containers](#pre-requirements-without-using-dev-containers)
    - [Pre-requirements using Dev Containers](#pre-requirements-using-dev-containers)
    - [Running the deployment](#running-the-deployment)
    - [Deployment considerations](#deployment-considerations)
    - [Running the Initial Setup](#running-the-initial-setup)
    - [Initial Setup considerations](#initial-setup-considerations)
    - [Running Data Ingest](#running-data-ingest)
    - [Data Ingest considerations](#data-ingest-considerations)
    - [Running Data Catalog](#running-data-catalog)
    - [Data catalog considerations](#data-catalog-considerations)
    - [Data Security model](#data-security-model)
      - [Basic](#basic)
      - [Advanced](#advanced)
    - [Data Security model considerations](#data-security-model-considerations)
      - [Basic](#basic-1)
      - [Advanced](#advanced-1)
  - [Issues and Workarounds](#issues-and-workarounds)
    - [Please register/re-register subscription xxxx with Microsoft.Purview resource provider.](#please-registerre-register-subscription-xxxx-with-microsoftpurview-resource-provider)
    - [Resource providers Microsoft.Storage and Microsoft.EventHub are not registered for subscription.](#resource-providers-microsoftstorage-and-microsofteventhub-are-not-registered-for-subscription)
  - [Removing the sample assets](#removing-the-sample-assets)

## About the Sample

The Data Exploration sample intent is provide the Data consumer a way to explore
and govern data previously shared by a data sharing mechanism. The sample was
written to be modularized so individual pieces can be orchestrated and reused as
needed. However in the sample they need to follow a particular order as they are
some dependencies between the modules in the behavior that is demonstrated.

The order is as follows:
- Deployment (bash and bicep)
- [Optional] Data Transfer (python) available
  [here]((https://github.com/Azure-Samples/modern-data-warehouse-dataops/tree/main/single_tech_samples/datashare))
- Initial Setup (python)
- Data Ingest (python)
- Data Catalog (python)
- Data Security - basic or advanced (python)

The components will be further described in the next sections.

## Deployment

The deployment module is the first step in the end-to-end sample and it
basically deploys all necessary infra structure and data that will be used by
the other modules. This module could be replaced by the Data marketplace
functionality when the sample becomes available.

## Data Transfer

The present sample, uploads two versions of the "adventureworkslt" database in
the data lake storage account as delta files and respective metadata and that is
done automatically during the deployment and is enough to demo the code of the
sample.

However, the user can complement the current sample with a Data sharing core
functionality as implemented in the
[eds-data-sharing-mechanism](https://github.com/Azure-Samples/modern-data-warehouse-dataops/tree/main/single_tech_samples/datashare)
sample so users can use their own data and that setup can be emulated and
feeding into the current sample.

The functionality implements a full end-to-end automation of the following
diagram:

![Data Transfer](./images/eds-repo-data-sharing-mechanism.drawio.svg)

## Initial Setup

This automation is responsible to Create Logins and DB Users in Synapse
Analytics for:
  - **Service Principal** created during the deployment in order to be used in
    the python modules that will be used after the deployment.
  - **Purview MSI** the Microsoft Purview Managed Identity, needs to access to
    Synapse in order to perform the scans.
  - **AAD Security Groups** in order to take advantage of AAD Security Groups
    for different data access levels, these AAD security groups need to be
    mapped to security logins and db users in Synapse so that the access is
    aligned accordingly.
 
## Data Ingestion

This module is responsible for the creation of assets in Synapse. Based on a
json file containing metadata information, the code will create one View for
each Delta Table stored in Azure Storage.

The metadata file contains information about the delta tables stored in Azure
Storage, including the major version, the path where the tables are stored, the
schema, a simple description, and the 'Sensitivity' attribute used to apply
security (either at table or at column level). Sensitivity can have three
values:

- low 
- medium
- high

The metadata files used for the sample can be found in this repo:

- [adventure_works_1.0.0.json](sample_data/_meta/adventure_works_1.0.0.json)
- [adventure_works_2.0.0.json](sample_data/_meta/adventure_works_2.0.0.json)

## Data Catalog

This module is responsible for interacting with Purview to catalog the newly
created assets in Synapse and enrich the entries using information supplied in
the metadata.

## Data Security 

The Data Security module is responsible for applying data security in Azure Data
Lake Storage and Synapse views and columns. The general rule is that if Security
is applied at table level, then any security attribute at column level is
ignored. The sample includes one table for each version (SaleLT_Customer) which
has no security attribute at table level in the metadata file, but has
'sensitivity' values for each column, and therefore the corresponding GRANT
statements handle column level security on that View in Synapse. There are two
types of data security supported by the module:

- **Data Security Basic**, based on fixed security groups in Azure Active
  Directory. (AD).
- **Data Security Advance**, based on a configuration file from KeyVault.

### Data Security Basic

The basic implementation of data security uses the `Sensitivity` information
gathered form the metadata file and applied in Purview by the Data Catalog
module. Depending on the value of that attribute (either at table or column
level), the AAD Groups created at deployment time should have visibility on the
data.

### Data Security Advanced

The advanced version of data security uses a json file
(`data_security_file.json` in the repo) to define the mapping between AAD Groups
and managed attributes in Purview. The default version of this file is
automatically generated at deployment time and stored in KeyVault, and it
defines a simple 1 to 1 mapping between 'Sensitivity' attribute and AAD Groups.
However, the file can and should be updated by the customer with his own AAD
Groups and Rules, which will be used to apply security.

## Running the Sample end-to-end
### Pre-requirements without using Dev Containers

Clone the repository and follow this prerequisites in order to run the sample:

- Login to Azure az login
- Install jq ```sudo apt-get install jq```
- Install Az CLI ```curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash```
    (for Ubunto or Debian).
- Create and define the deployment environment variables in a scr/.env file that
  should follow the structure described in src/.env.template. For the deployment
  piece the environment variables are:
  - export PROJECT=<PROJECT_NAME>
  - export AZURE_SUBSCRIPTION_ID=<SUBSCRIPTION_ID>
  - export DEPLOYMENT_ID=dep1 (or any other string). NOTE: if the deployment
    fails, you need either to delete the resources created or use a different
    DEPLOYMENT_ID.
  - export AZURE_LOCATION=westeurope (or any other Azure location)
- Define remaining environment variables as described in the src/.env.template
  file if needed:
  - SYNAPSE_DRIVER='{ODBC Driver 17 for SQL Server}'
  - SYNAPSE_DATABASE=adventureworks-db
  - SYNAPSE_DATABASE_SCHEMA=SalesLT
  - ADLS_CONTAINER_NAME=adventureworkslt
  - PURVIEW_COLLECTION_NAME=AdventureWorks
  - DATA_SECURITY_ATTRIBUTE=Sensitivity
  - SECURITY_MANAGED_ATTRIBUTE_GROUP=Metadata
  - SECURITY_MANAGED_ATTRIBUTE_NAME=SecurityGroup
### Pre-requirements using Dev Containers

To use a Dev Container, you need to have the following software in addition to
the previous pre-requisites:

- Docker
- Visual Studio Code Remote Development Extension Pack

In order to open the project in a container follow the following steps:

- Open Visual Studio Code and clone the repository.
- Use the .env.template file located in \enterprise-data-sharing\src to create a
 file named `.env` with the selected values for the current deployment. Some
 variables are pre-populated with default values.
- Hit Control-Shift-P to open the command palette and type Dev Containers: Open
  Folder in Container ...
- When prompted, select the directory \enterprise-data-sharing
- Wait for the container to build, check the logs for more information.

### Running the deployment

After all the pre-requisites are implemented, the deployment can be triggered.
Navigate to the directory /enterprise-data-sharing/ and run the following
command:

```bash
az login --tenant <TENANT_ID>
az account set -s <SUBSCRIPTION_ID>
cd src
chmod +x ./deploy.sh
set -a && source /src/.env && bash ./deploy.sh 
```
### Deployment considerations

The script firstly deploys the infrastructure that is required to demonstrate
the objectives of the sample. On successful completion, the infrastructure is
composed by:

- one resource group, named <PROJECT_NAME><DEPLOYMENT_ID>-rg, and within the
  resource group you can find:
  - one storage account for internal Synapse use, named
    <PROJECT_NAME>st2<DEPLOYMENT_ID>
  - one storage account that acts as the data lake to store the NYC Taxi Data,
    named <PROJECT_NAME>st1<DEPLOYMENT_ID>
    - the data lake contains a container called "adventureworkslt" and under the
      container there are 2 versions of the SalesLT schema v1 and v2 and
      respective data.
  - one _meta folder with the schema information for each version:
    adventure_works_1.0.0.json and adventure_works_2.0.0.json.
  - a Synapse workspace named syws<DEPLOYMENT_ID>, that includes a Serverless
    pool and a Spark pool
  - a Purview account, named pview<PROJECT_NAME><DEPLOYMENT_ID>
  - three AD Groups, named:
    - AADGR<PROJECT_NAME><DEPLOYMENT_ID><LOW> - representing a group with low
      access rights
    - AADGR<PROJECT_NAME><DEPLOYMENT_ID><MED> - representing a group with medium
      access rights
    - AADGR<PROJECT_NAME><DEPLOYMENT_ID><HIG> - representing a group with high
      access rights
  - a key vault resource named, <PROJECT_NAME><DEPLOYMENT_ID>
  - one resource group named <PROJECT_NAME>-syn-mrg-<DEPLOYMENT_ID>, for
    internal use of Synapse
  - one resource group named <PROJECT_NAME>-pview-mrg-<DEPLOYMENT_ID>, for
    internal use of Purview
  - a service principal named <PROJECT_NAME>-<DEPLOYMENT_ID>-sp, to be used by
    the python code after the deployment

### Running the Initial Setup

To run the initial setup confirm that:
- The `.env` file has been created with proper values.
- The deployment module ran successfully.
- The user should be logged in with Azure CLI credentials.
 
```cli
az login --tenant <TENANT_ID>
az account set -s <SUBSCRIPTION_ID>
```
And run the setup proceed with the following commands: 
``` cd src 
initial_setup.py
```

### Initial Setup considerations

After the initial setup runs successfully, the following actions are completed:

- Main database created in Synapse, based on the content of the env variable
  `SYNAPSE_DATABASE`, where all the Views will be created by the
  `data_ingest.py` module.
- `LOGIN` created in Synapse for the Service Principal created at deployment
  time. This specific SP credentials are used to run any other module in this
  sample.
- `DATABASE USER` created with `db_owner` role for the Service Principal, that
  allows access items in the DB.
- `LOGIN` and a `DATABASE USER` with `db_datareader` role for the Purview
  account (MSI) created at deployment time.
- `LOGIN` and a `DATABASE USER` with no role for the each Security Groups
  created at deployment time. By default, three security groups are created to
  be used in the `data_security_basic.py` module.

### Running Data Ingest

To run the Data Ingest module confirm that:
- The `.env` file has been created with proper values.
- The deployment module ran successfully.
- The initial setup module ran successfully.

And run the following command:

`data_ingest.py`

### Data Ingest considerations

The main code for data ingestion includes the following operations:

- Retrieves metadata files from the storage container provided as env variable,
  which are located in a specific folder named `_meta`.
- For each metadata file, creates in Synapse:
  - an `external data source`, using the path of the referred delta tables
  - a schema, based on the `path` property in the specific metadata file and the
    env variable `SYNAPSE_DATABASE_SCHEMA` (e.g.: `v1_SalesLT`)
  - one View for each delta table. The name of each view is based on the env
    variable `SYNAPSE_DATABASE_SCHEMA` and the table name in the metadata file
    (e.g.: `SalesLT_Customer`)
- Print the list of Views created in Synapse
### Running Data Catalog

To run the Data Catalog module confirm that:
- The `.env` file has been created with proper values.
- The deployment module ran successfully.
- The initial setup module ran successfully.
- The data ingest module ran successfully.

And run the following command:
  
`data_catalog.py`

### Data catalog considerations

The main code for data catalog includes the following operations:

- Creates a collection to hold all new assets
- Registers the Synapse database as a data source
- Creates a scan definition
- Triggers the scan and waits for its completion
- Updates the following metadata:
  - Views and column descriptions
  - Column data types
  - Adds a Sensitivity field to views and columns using a [Managed
    Attribute](https://learn.microsoft.com/en-us/azure/purview/how-to-managed-attributes)
- Creates a collection hierarchy based on database schema information and
  organizes assets accordingly

Note: Managed attributes, at the time of this writing, cannot be removed from
Purview and can only be expired.

### Data Security model

There are two options to implement the security model. The basic version - which
is the default version and there is no need to customize any setting and the
advanced version that allows to extend the security model to other security
groups that the user might need in their specific user case.
#### Basic

To run the Security model basic module confirm that:

  - The `.env` file has been created with proper values.
  - The deployment module ran successfully.
  - The initial setup module ran successfully.
  - The data ingest module ran successfully.

The simpler version, which uses three static Security Groups created at
deployment time can be ran using the following command: 

  `data_security_basic.py`

#### Advanced

The customizable version, which uses the data security json content stored in
KeyVault to get security groups and rules to apply security. The security json
content looks as follow and is stored in Key Vault under "securityFile" name.

 ```json
{
  "security_groups": "[<AADGR<PROJECT_NAME><DEPLOYMENT_ID>LOW,AADGR<PROJECT_NAME><DEPLOYMENT_ID>MED,AADGR<PROJECT_NAME><DEPLOYMENT_ID>HIG]",
  "rules": [
    {
      "constraints": {
        "sensitivity": "Low"
      },
      "security_group": "AADGR<PROJECT_NAME><DEPLOYMENT_ID>LOW"
    },
    {
      "constraints": {
        "sensitivity": "Medium"
      },
      "security_group": "AADGR<PROJECT_NAME><DEPLOYMENT_ID>MED"
    },
    {
      "constraints": {
        "sensitivity": "High"
      },
      "security_group": "AADGR<PROJECT_NAME><DEPLOYMENT_ID>HIG"
    }
  ]
}
 ```

To run the Data Catalog module confirm that:
- The data security file must be updated by the user (we need at least 2
  versions of the secret in KeyVault). That means the user can extend or change
  the current security groups to their own use case.
- If new AD Security Groups are added in the data security file, then these
  manual operations are required before running the `data_security_advanced.py`
  script:

  - Run the following code in Synapse, to create LOGIN for each one of the new
    groups:

    ```sql
    CREATE LOGIN [AD-Group_name] FROM EXTERNAL PROVIDER
    ```

  - Get the Object-ID of each new AD Group from Azure AAD and store it in
    KeyVault with the following convention name: `OBJID-<New-AD-Group-Name>`
  - The `.env` file has been created with proper values.
  - The deployment module ran successfully.
  - The initial setup module ran successfully.
  - The data ingest module ran successfully.
  
  And run the following command:

  `data_security_advanced.py`

### Data Security model considerations

#### Basic

The main code for security basic includes the following operations:

- Assign the security managed attribute to all items in Purview. A new Managed
  Attribute (which name and group are configurable in `.env` file) is added to
  each asset in Purview, as a simple one to one mapping with the `Sensitivity`
  attribute. This is useful to have immediate understanding of which group can
  access the data, directly in Purview.
- Get the value of all views and security attributes from Purview. This step
  leverages the previous one, but it's separated in order to handle also manual
  updates of the assigned Security Group directly in Purview.
- Generate GRANT statements and apply security to Synapse assets. After this
  step, users belonging to a specific AAD Group will be able to see and query
  only the allowed Views in Synapse.
- Apply access control lists (ACL) to all folders and files. This step is
  required to make sure that users cannot check data directly in data lake if
  they are not allowed.
- Apply ACL to the root directory so that all groups have access at the root
  level.

#### Advanced

The main code for security advanced includes the following operations:

- Read the security file from KeyVault and validate the content:
  - the secret in KeyVault (json content) has at least 2 versions (the default
    one + at least one update from the user)
  - the json content should include both 'security_groups' and 'rules' sections
  - the security groups used for rules should be the same as the ones in the
    'security_groups' section
- Assign the security managed attribute to all items in Purview.  For each asset
  in Purview, all the rules in the data security file are evaluated in order.
  The first match between managed attribute(s) value from Purview and the rule
  in the data security file defines the AAD Group who should have access to the
  data. Similarly to the basic data security implementation, the value of this
  Security Group is stored in Purview to provide a clear and immediate
  information in the catalog.
- Get the value of all views and security attributes from Purview.
- Generate GRANT statements and apply security to Synapse assets.
- Apply access control lists (ACL) to all folders and files.
- Apply ACL to the root directory so that all groups have access at the root
  level.
## Issues and Workarounds

### Please register/re-register subscription xxxx with Microsoft.Purview resource provider.

The used subscription must have the Microsoft.Purview provider registered.

### Resource providers Microsoft.Storage and Microsoft.EventHub are not registered for subscription.

The used subscription must have the Microsoft.EventHub and Microsoft.Storage
registered.

## Removing the sample assets

You can clean up all the assets and avoid additional costs by deleting the main resource group:

```bash
az group delete --resource-group <PROJECT_NAME><DEPLOYMENT_ID>-rg
```
and remove the AAD groups deployed:
- AADGR<PROJECT_NAME><DEPLOYMENT_ID>_LOW
- AADGR<PROJECT_NAME><DEPLOYMENT_ID>_MEDIUM
- AADGR<PROJECT_NAME><DEPLOYMENT_ID>_HIGH