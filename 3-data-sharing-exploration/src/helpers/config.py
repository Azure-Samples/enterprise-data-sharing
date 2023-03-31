import logging
import os

from dotenv import load_dotenv
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential
from azure.core.exceptions import (
    HttpResponseError,
    ResourceNotFoundError,
    ServiceRequestError,
)


class Configuration:
    def __init__(self, configuration_file: str = ".env"):
        self._logger = logging.getLogger(__name__)

        # from env variables
        self._azure_location = ""
        self._azure_subscription_id = ""
        self._project = ""
        self._deployment_id = ""
        self._synapse_driver = ""
        self._synapse_database = ""
        self._synapse_database_schema = ""
        self._adls_container_name = ""
        self._purview_collection_name = ""
        self._data_security_attribute = ""
        self._security_managed_attribute_group = ""
        self._security_managed_attribute_name = ""

        self._objid_prefix = ""

        # built from env variables
        self._synapse_workspace_name = ""
        self._resource_group_name = ""
        self._storage_account_name = ""
        self._purview_account_name = ""
        self._keyvault_name = ""
        self._data_security_group_low = ""
        self._data_security_group_medium = ""
        self._data_security_group_high = ""

        # from  keyvault
        self._azure_client_id = ""
        self._azure_tenant_id = ""
        self._azure_client_secret = ""
        self._azure_client_name = ""
        self._security_file_secret = ""

        self._logger.info(f"Initializing config using values in {configuration_file}")
        if not load_dotenv(configuration_file, override=True):
            self._logger.error(f"{configuration_file} not found!")

        self._keyvault_client = ""

    # From env

    @property
    def azure_location(self):
        if self._azure_location == "":
            value = os.getenv("AZURE_LOCATION")
            if value is None:
                msg = "AZURE_LOCATION is not set"
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._azure_location = value
        return self._azure_location

    @azure_location.setter
    def azure_location(self, value):
        self._azure_location = value

    @property
    def azure_subscription_id(self):
        if self._azure_subscription_id == "":
            value = os.getenv("AZURE_SUBSCRIPTION_ID")
            if value is None:
                msg = "AZURE_SUBSCRIPTION_ID is not set"
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._azure_subscription_id = value
        return self._azure_subscription_id

    @azure_subscription_id.setter
    def azure_subscription_id(self, value):
        self._azure_subscription_id = value

    @property
    def project(self):
        if self._project == "":
            value = os.getenv("PROJECT")
            if value is None:
                msg = "PROJECT is not set"
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._project = value
        return self._project

    @project.setter
    def project(self, value):
        self._project = value

    @property
    def deployment_id(self):
        if self._deployment_id == "":
            value = os.getenv("DEPLOYMENT_ID")
            if value is None:
                msg = "DEPLOYMENT_ID is not set"
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._deployment_id = value
        return self._deployment_id

    @deployment_id.setter
    def deployment_id(self, value):
        self._deployment_id = value

    @property
    def synapse_driver(self):
        if self._synapse_driver == "":
            value = os.getenv("SYNAPSE_DRIVER", "")
            if value is None:
                msg = "SYNAPSE_DRIVER is not set"
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._synapse_driver = value
        return self._synapse_driver

    @synapse_driver.setter
    def synapse_driver(self, value):
        self._synapse_driver = value

    @property
    def synapse_database(self):
        if self._synapse_database == "":
            value = os.getenv("SYNAPSE_DATABASE", "")
            if value is None:
                msg = "SYNAPSE_DATABASE is not set"
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._synapse_database = value
        return self._synapse_database

    @synapse_database.setter
    def synapse_database(self, value):
        self._synapse_database = value

    @property
    def synapse_database_schema(self):
        if self._synapse_database_schema == "":
            value = os.getenv("SYNAPSE_DATABASE_SCHEMA", "")
            if value is None:
                msg = "SYNAPSE_DATABASE_SCHEMA is not set"
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._synapse_database_schema = value
        return self._synapse_database_schema

    @synapse_database_schema.setter
    def synapse_database_schema(self, value):
        self._synapse_database_schema = value

    @property
    def adls_container_name(self):
        if self._adls_container_name == "":
            value = os.getenv("ADLS_CONTAINER_NAME", "")
            if value is None:
                msg = "ADLS_CONTAINER_NAME is not set"
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._adls_container_name = value
        return self._adls_container_name

    @adls_container_name.setter
    def adls_container_name(self, value):
        self._adls_container_name = value

    @property
    def purview_collection_name(self):
        if self._purview_collection_name == "":
            value = os.getenv("PURVIEW_COLLECTION_NAME")
            if value is None:
                msg = "PURVIEW_COLLECTION_NAME is not set"
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._purview_collection_name = value
        return self._purview_collection_name

    @purview_collection_name.setter
    def purview_collection_name(self, value):
        self._purview_collection_name = value

    @property
    def data_security_attribute(self):
        if self._data_security_attribute == "":
            value = os.getenv("DATA_SECURITY_ATTRIBUTE", "")
            if value is None:
                msg = "DATA_SECURITY_ATTRIBUTE is not set"
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._data_security_attribute = value
        return self._data_security_attribute

    @data_security_attribute.setter
    def data_security_attribute(self, value):
        self._data_security_attribute = value

    @property
    def security_managed_attribute_group(self):
        if self._security_managed_attribute_group == "":
            value = os.getenv("SECURITY_MANAGED_ATTRIBUTE_GROUP", "")
            if value is None:
                msg = "SECURITY_MANAGED_ATTRIBUTE_GROUP is not set"
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._security_managed_attribute_group = value
        return self._security_managed_attribute_group

    @security_managed_attribute_group.setter
    def security_managed_attribute_group(self, value):
        self._security_managed_attribute_group = value

    @property
    def security_managed_attribute_name(self):
        if self._security_managed_attribute_name == "":
            value = os.getenv("SECURITY_MANAGED_ATTRIBUTE_NAME", "")
            if value is None:
                msg = "SECURITY_MANAGED_ATTRIBUTE_NAME is not set"
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._security_managed_attribute_name = value
        return self._security_managed_attribute_name

    @security_managed_attribute_name.setter
    def security_managed_attribute_name(self, value):
        self._security_managed_attribute_name = value

    @property
    def objid_prefix(self):
        if self._objid_prefix == "":
            self._security_managed_attribute_name = "OBJID-"
        return self._security_managed_attribute_name

    @objid_prefix.setter
    def objid_prefix(self, value):
        self._objid_prefix = value

    # Built from env variables

    @property
    def synapse_workspace_name(self):
        if self._synapse_workspace_name == "":
            if self.deployment_id == "":
                msg = "SYNAPSE_WORSPACE_NAME requires DEPLOYMENT_ID, which is not set."
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._synapse_workspace_name = f"syws{self.deployment_id}"
        return self._synapse_workspace_name

    @synapse_workspace_name.setter
    def synapse_workspace_name(self, value):
        self._synapse_workspace_name = value

    @property
    def resource_group_name(self):
        if self._resource_group_name == "":
            if self.deployment_id == "" or self.project == "":
                msg = (
                    "RESOURCE_GROUP_NAME requires DEPLOYMENT_ID and PROJECT, "
                    "make sure both env variables are set."
                )
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._resource_group_name = f"{self.project}-{self.deployment_id}-rg"
        return self._resource_group_name

    @resource_group_name.setter
    def resource_group_name(self, value):
        self._resource_group_name = value

    @property
    def storage_account_name(self):
        if self._storage_account_name == "":
            if self.deployment_id == "" or self.project == "":
                msg = (
                    "STORAGE_ACCOUNT_NAME requires DEPLOYMENT_ID and PROJECT, "
                    "make sure both env variables are set."
                )
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._storage_account_name = f"{self.project}st1{self.deployment_id}"
        return self._storage_account_name

    @storage_account_name.setter
    def storage_account_name(self, value):
        self._storage_account_name = value

    @property
    def purview_account_name(self):
        if self._purview_account_name == "":
            if self.deployment_id == "" or self.project == "":
                msg = (
                    "PURVIEW_ACCOUNT_NAME requires DEPLOYMENT_ID and PROJECT, "
                    "make sure both env variables are set."
                )
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._purview_account_name = f"pview{self.project}{self.deployment_id}"
        return self._purview_account_name

    @purview_account_name.setter
    def purview_account_name(self, value):
        self._purview_account_name = value

    @property
    def keyvault_name(self):
        if self._keyvault_name == "":
            if self.deployment_id == "" or self.project == "":
                msg = (
                    "KEYVAULT_NAME requires DEPLOYMENT_ID and PROJECT, "
                    "make sure both env variables are set."
                )
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._keyvault_name = f"{self.project}kv{self.deployment_id}"
        return self._keyvault_name

    @keyvault_name.setter
    def keyvault_name(self, value):
        self._keyvault_name = value

    @property
    def keyvault_client(self):
        if self._keyvault_client == "":
            if self.keyvault_name == "":
                msg = (
                    "KEYVAULT_CLIENT requires KEYVAULT_NAME, which is not set."
                )
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._keyvault_client = SecretClient(
                    credential=DefaultAzureCredential(),
                    vault_url=f"https://{self._keyvault_name}.vault.azure.net/",
                )
        return self._keyvault_client

    @keyvault_client.setter
    def keyvault_client(self, value):
        self._keyvault_client = value

    @property
    def data_security_group_low(self):
        if self._data_security_group_low == "":
            if self.deployment_id == "" or self.project == "":
                msg = (
                    "DATA_SECURITY_GROUP_LOW requires DEPLOYMENT_ID and PROJECT, "
                    "make sure both env variables are set."
                )
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._data_security_group_low = (
                    f"AADGR{self.project}{self.deployment_id}LOW"
                )
        return self._data_security_group_low

    @data_security_group_low.setter
    def data_security_group_low(self, value):
        self._data_security_group_low = value

    @property
    def data_security_group_medium(self):
        if self._data_security_group_medium == "":
            if self.deployment_id == "" or self.project == "":
                msg = (
                    "DATA_SECURITY_GROUP_MEDIUM requires DEPLOYMENT_ID and PROJECT, "
                    "make sure both env variables are set."
                )
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._data_security_group_medium = (
                    f"AADGR{self.project}{self.deployment_id}MED"
                )
        return self._data_security_group_medium

    @data_security_group_medium.setter
    def data_security_group_medium(self, value):
        self._data_security_group_medium = value

    @property
    def data_security_group_high(self):
        if self._data_security_group_high == "":
            if self.deployment_id == "" or self.project == "":
                msg = (
                    "DATA_SECURITY_GROUP_HIGH requires DEPLOYMENT_ID and PROJECT, "
                    "make sure both env variables are set."
                )
                self._logger.error(msg)
                raise ValueError(msg)
            else:
                self._data_security_group_high = (
                    f"AADGR{self.project}{self.deployment_id}HIG"
                )
        return self._data_security_group_high

    @data_security_group_high.setter
    def data_security_group_high(self, value):
        self._data_security_group_high = value

    # From KeyVault

    @property
    def azure_client_id(self):
        if self._azure_client_id == "":
            self._azure_client_id = self._get_secret_from_kv(
                var_name="AZURE_CLIENT_ID", secret_name="spAppId"
            )
        return self._azure_client_id.value

    @azure_client_id.setter
    def azure_client_id(self, value):
        self._azure_client_id = value

    @property
    def azure_tenant_id(self):
        if self._azure_tenant_id == "":
            self._azure_tenant_id = self._get_secret_from_kv(
                var_name="AZURE_TENANT_ID", secret_name="spAppTenantId"
            )
        return self._azure_tenant_id.value

    @azure_tenant_id.setter
    def azure_tenant_id(self, value):
        self._azure_tenant_id = value

    @property
    def azure_client_secret(self):
        if self._azure_client_secret == "":
            self._azure_client_secret = self._get_secret_from_kv(
                var_name="AZURE_CLIENT_SECRET", secret_name="spAppPass"
            )
        return self._azure_client_secret.value

    @azure_client_secret.setter
    def azure_client_secret(self, value):
        self._azure_client_secret = value

    @property
    def azure_client_name(self):
        if self._azure_client_name == "":
            self._azure_client_name = self._get_secret_from_kv(
                var_name="AZURE_CLIENT_NAME", secret_name="spAppName"
            )
        return self._azure_client_name.value

    @azure_client_name.setter
    def azure_client_name(self, value):
        self._azure_client_name = value

    @property
    def security_file_secret(self):
        if self._security_file_secret == "":
            self._security_file_secret = "securityFile"
        return self._security_file_secret

    @security_file_secret.setter
    def security_file_secret(self, value):
        self._security_file_secret = value

    def _get_secret_from_kv(self, var_name: str, secret_name: str):
        """
        Utility method to get secrets from KeyVault and handle exceptions.
        """
        if self.keyvault_client == "":
            msg = f"{var_name} requires KEYVAULT_NAME, which is not set."
            self._logger.error(msg)
            raise ValueError(msg)
        else:
            try:
                return self.keyvault_client.get_secret(secret_name)
            except (
                ResourceNotFoundError,
                HttpResponseError,
                ServiceRequestError,
            ) as ex:
                self._logger.error(
                    f"Unable to retrieve secret {secret_name} from key vault. {ex}"
                )
                return None
