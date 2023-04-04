import logging
import os

from dotenv import load_dotenv


class Configuration:
    def __init__(self, configuration_file: str = ".env"):
        self._logger = logging.getLogger(__name__)

        self._purview_account_name = ""
        self._purview_collection_name = ""
        self._storage_account_name = ""
        self._synapse_workspace_name = ""
        self._synapse_resource_group_name = ""
        self._synapse_subscription_id = ""
        self._synapse_region = ""
        self._container_name = ""
        self._synapse_driver = ""
        self._synapse_server = ""
        self._synapse_database = ""
        self._schema_name = ""
        self._azure_client_id = ""
        self._azure_client_secret = ""
        self._data_security_attribute = ""
        self._azure_tenant_id = ""
        self._azure_keyvault_uri = ""
        self._azure_keyvault_secret = ""
        self._data_security_group_low = ""
        self._data_security_group_medium = ""
        self._data_security_group_high = ""
        self._security_group_a_oid = ""
        self._security_group_b_oid = ""
        self._security_group_c_oid = ""

        self._logger.info(f"Initializing config using values in {configuration_file}")
        if not load_dotenv(configuration_file):
            self._logger.warning(f"{configuration_file} not found!")

    @property
    def purview_account_name(self):
        if self._purview_account_name == "":
            value = os.getenv("PURVIEW_ACCOUNT_NAME")
            if value is None:
                self._logger.warning("PURVIEW_ACCOUNT_NAME is not set")
            else:
                self._purview_account_name = value
        return self._purview_account_name

    @purview_account_name.setter
    def purview_account_name(self, value):
        self._purview_account_name = value

    @property
    def purview_collection_name(self):
        if self._purview_collection_name == "":
            value = os.getenv("PURVIEW_COLLECTION_NAME")
            if value is None:
                self._logger.warning("PURVIEW_COLLECTION_NAME is not set")
            else:
                self._purview_collection_name = value
        return self._purview_collection_name

    @purview_collection_name.setter
    def purview_collection_name(self, value):
        self._purview_collection_name = value

    @property
    def storage_account_name(self):
        if self._storage_account_name == "":
            value = os.getenv("STORAGE_ACCOUNT_NAME", "")
            if value is None:
                self._logger.warning("STORAGE_ACCOUNT_NAME is not set")
            else:
                self._storage_account_name = value
        return self._storage_account_name

    @storage_account_name.setter
    def storage_account_name(self, value):
        self._storage_account_name = value

    @property
    def synapse_workspace_name(self):
        if self._synapse_workspace_name == "":
            value = os.getenv("SYNAPSE_WORKSPACE_NAME", "")
            if value is None:
                self._logger.warning("SYNAPSE_WORKSPACE_NAME is not set")
            else:
                self._synapse_workspace_name = value
        return self._synapse_workspace_name

    @synapse_workspace_name.setter
    def synapse_workspace_name(self, value):
        self._synapse_workspace_name = value

    @property
    def synapse_resource_group_name(self):
        if self._synapse_resource_group_name == "":
            value = os.getenv("SYNAPSE_RESOURCE_GROUP_NAME", "")
            if value is None:
                self._logger.warning("SYNAPSE_RESOURCE_GROUP_NAME is not set")
            else:
                self._synapse_resource_group_name = value
        return self._synapse_resource_group_name

    @synapse_resource_group_name.setter
    def synapse_resource_group_name(self, value):
        self._synapse_resource_group_name = value

    @property
    def synapse_subscription_id(self):
        if self._synapse_subscription_id == "":
            value = os.getenv("SYNAPSE_SUBSCRIPTION_ID", "")
            if value is None:
                self._logger.warning("SYNAPSE_SUBSCRIPTION_ID is not set")
            else:
                self._synapse_subscription_id = value
        return self._synapse_subscription_id

    @synapse_subscription_id.setter
    def synapse_subscription_id(self, value):
        self._synapse_subscription_id = value

    @property
    def synapse_region(self):
        if self._synapse_region == "":
            value = os.getenv("SYNAPSE_REGION", "")
            if value is None:
                self._logger.warning("SYNAPSE_REGION is not set")
            else:
                self._synapse_region = value
        return self._synapse_region

    @synapse_region.setter
    def synapse_region(self, value):
        self._synapse_region = value

    @property
    def container_name(self):
        if self._container_name == "":
            value = os.getenv("CONTAINER_NAME", "")
            if value is None:
                self._logger.warning("CONTAINER_NAME is not set")
            else:
                self._container_name = value
        return self._container_name

    @container_name.setter
    def container_name(self, value):
        self._container_name = value

    @property
    def synapse_driver(self):
        if self._synapse_driver == "":
            value = os.getenv("SYNAPSE_DRIVER", "")
            if value is None:
                self._logger.warning("SYNAPSE_DRIVER is not set")
            else:
                self._synapse_driver = value
        return self._synapse_driver

    @synapse_driver.setter
    def synapse_driver(self, value):
        self._synapse_driver = value

    @property
    def synapse_server(self):
        if self._synapse_server == "":
            value = os.getenv("SYNAPSE_SERVER", "")
            if value is None:
                self._logger.warning("SYNAPSE_SERVER is not set")
            else:
                self._synapse_server = value
        return self._synapse_server

    @synapse_server.setter
    def synapse_server(self, value):
        self._synapse_server = value

    @property
    def synapse_database(self):
        if self._synapse_database == "":
            value = os.getenv("SYNAPSE_DATABASE", "")
            if value is None:
                self._logger.warning("SYNAPSE_DATABASE is not set")
            else:
                self._synapse_database = value
        return self._synapse_database

    @synapse_database.setter
    def synapse_database(self, value):
        self._synapse_database = value

    @property
    def schema_name(self):
        if self._schema_name == "":
            value = os.getenv("SCHEMA_NAME", "")
            if value is None:
                self._logger.warning("SCHEMA_NAME is not set")
            else:
                self._schema_name = value
        return self._schema_name

    @schema_name.setter
    def schema_name(self, value):
        self._schema_name = value

    @property
    def azure_client_id(self):
        if self._azure_client_id == "":
            value = os.getenv("AZURE_CLIENT_ID", "")
            if value is None:
                self._logger.warning("AZURE_CLIENT_ID is not set")
            else:
                self._azure_client_id = value
        return self._azure_client_id

    @azure_client_id.setter
    def azure_client_id(self, value):
        self._azure_client_id = value

    @property
    def azure_tenant_id(self):
        if self._azure_tenant_id == "":
            value = os.getenv("AZURE_TENANT_ID", "")
            if value is None:
                self._logger.warning("AZURE_TENANT_ID is not set")
            else:
                self._azure_tenant_id = value
        return self._azure_tenant_id

    @azure_tenant_id.setter
    def azure_tenant_id(self, value):
        self._azure_tenant_id = value

    @property
    def azure_client_secret(self):
        if self._azure_client_secret == "":
            value = os.getenv("AZURE_CLIENT_SECRET", "")
            if value is None:
                self._logger.warning("AZURE_CLIENT_SECRET is not set")
            else:
                self._azure_client_secret = value
        return self._azure_client_secret

    @azure_client_secret.setter
    def azure_client_secret(self, value):
        self._azure_client_secret = value

    @property
    def data_security_attribute(self):
        if self._data_security_attribute == "":
            value = os.getenv("DATA_SECURITY_ATTRIBUTE", "")
            if value is None:
                self._logger.warning("DATA_SECURITY_ATTRIBUTE is not set")
            else:
                self._data_security_attribute = value
        return self._data_security_attribute

    @data_security_attribute.setter
    def data_security_attribute(self, value):
        self._data_security_attribute = value

    @property
    def azure_keyvault_uri(self):
        if self._azure_keyvault_uri == "":
            value = os.getenv("KEY_VAULT_URI", "")
            if value is None:
                self._logger.warning("KEY_VAULT_URI is not set")
            else:
                self._azure_keyvault_uri = value
        return self._azure_keyvault_uri

    @azure_keyvault_uri.setter
    def azure_keyvault_uri(self, value):
        self._azure_keyvault_uri = value

    @property
    def azure_keyvault_secret(self):
        if self._azure_keyvault_secret == "":
            value = os.getenv("KEY_VAULT_SECRET", "")
            if value is None:
                self._logger.warning("KEY_VAULT_SECRET is not set")
            else:
                self._azure_keyvault_secret = value
        return self._azure_keyvault_secret

    @azure_keyvault_secret.setter
    def azure_keyvault_secret(self, value):
        self._azure_keyvault_secret = value

    @property
    def data_security_group_low(self):
        if self._data_security_group_low == "":
            value = os.getenv("DATA_SECURITY_GROUP_LOW", "")
            if value is None:
                self._logger.warning("DATA_SECURITY_GROUP_LOW is not set")
            else:
                self._data_security_group_low = value
        return self._data_security_group_low

    @data_security_group_low.setter
    def data_security_group_low(self, value):
        self._data_security_group_low = value

    @property
    def data_security_group_medium(self):
        if self._data_security_group_medium == "":
            value = os.getenv("DATA_SECURITY_GROUP_MEDIUM", "")
            if value is None:
                self._logger.warning("DATA_SECURITY_GROUP_MEDIUM is not set")
            else:
                self._data_security_group_medium = value
        return self._data_security_group_medium

    @data_security_group_medium.setter
    def data_security_group_medium(self, value):
        self._data_security_group_medium = value

    @property
    def data_security_group_high(self):
        if self._data_security_group_high == "":
            value = os.getenv("DATA_SECURITY_GROUP_HIGH", "")
            if value is None:
                self._logger.warning("DATA_SECURITY_GROUP_HIGH is not set")
            else:
                self._data_security_group_high = value
        return self._data_security_group_high

    @data_security_group_high.setter
    def data_security_group_high(self, value):
        self._data_security_group_high = value

    @property
    def security_group_a_oid(self):
        if self._security_group_a_oid == "":
            value = os.getenv("SECURITY_GROUP_A_OID", "")
            if value is None:
                self._logger.warning("SECURITY_GROUP_A_OID is not set")
            else:
                self._security_group_a_oid = value
        return self._security_group_a_oid

    @security_group_a_oid.setter
    def security_group_a_oid(self, value):
        self._security_group_a_oid = value

    @property
    def security_group_b_oid(self):
        if self._security_group_b_oid == "":
            value = os.getenv("SECURITY_GROUP_B_OID", "")
            if value is None:
                self._logger.warning("SECURITY_GROUP_B_OID is not set")
            else:
                self._security_group_b_oid = value
        return self._security_group_b_oid

    @security_group_b_oid.setter
    def security_group_b_oid(self, value):
        self._security_group_b_oid = value

    @property
    def security_group_c_oid(self):
        if self._security_group_c_oid == "":
            value = os.getenv("SECURITY_GROUP_C_OID", "")
            if value is None:
                self._logger.warning("SECURITY_GROUP_C_OID is not set")
            else:
                self._security_group_c_oid = value
        return self._security_group_c_oid

    @security_group_c_oid.setter
    def security_group_c_oid(self, value):
        self._security_group_c_oid = value
