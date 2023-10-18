# Enterprise Data Sharing managed application

## Introduction

This part of the repository contains the code for the Enterprise Data Sharing managed application. A managed application is a collection of Azure resources that can be deployed to an Azure subscription either using the Azure Marketplace or the Service Catalog approach.
To learn more about managed applications in Azure, you can take a look [here](https://learn.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/overview)

## Quickstart

To help you deploy the managed application definition and instanciate from it, we are providing a shell script that will help you. The script is located in the `scripts` folder and is called [provision.sh](./scripts/provision.sh). The script will deploy the managed application definition and instanciate from it. The script will require you to provide some parameters in a json file of which you can find a template [here](./scripts/provision.config.template.json). You will need to rename the file to `provision.config.json` and provide values for the following parameters:

Once your `provision.config.json` is ready, you can run the script as follows:

```bash
bash provision.sh
```
