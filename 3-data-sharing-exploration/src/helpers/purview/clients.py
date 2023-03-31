"""
Purview Client helper module
"""
from azure.identity import DefaultAzureCredential
from azure.purview.administration.account import PurviewAccountClient
from azure.purview.catalog import PurviewCatalogClient
from azure.purview.scanning import PurviewScanningClient


class ClientHelper:
    """
    Purview SDK helper functions
    """

    def __init__(self, account_name: str):
        self._account_name = account_name

    def get_credentials(self):
        """
        Create credentials for connecting to Purview
        """
        credentials = DefaultAzureCredential(exclude_visual_studio_code_credential=True)
        return credentials

    def get_scanning_client(self):
        """
        Create Purview scanning client
        """
        credentials = self.get_credentials()
        client = PurviewScanningClient(
            endpoint=f"https://{self._account_name}.scan.purview.azure.com",
            credential=credentials,
            logger_enable=True,
        )

        return client

    def get_account_client(self):
        """
        Create Purview account client
        """
        credentials = self.get_credentials()
        client = PurviewAccountClient(
            endpoint=f"https://{self._account_name}.purview.azure.com/",
            credential=credentials,
            logger_enable=True,
        )
        return client

    def get_catalog_client(self):
        """
        Create Purview catalog client
        """
        credentials = self.get_credentials()
        client = PurviewCatalogClient(
            endpoint=f"https://{self._account_name}.purview.azure.com/",
            credential=credentials,
            logger_enable=True,
        )
        return client
