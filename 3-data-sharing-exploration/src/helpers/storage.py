import logging
from typing import List, Union

from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

from .metadata import MetadataFile


class StorageHelper:
    """Contains methods for interacting with Azure Blob Storage"""

    def __init__(self, account_name: str):
        """
        Initialize the StorageHelper instance for a specific Azure Blob Storage account.

        Parameters:
            account_name (str): name of the Azure Blob Storage account.

        Raises:
            ValueError: if account_name is empty.
        """
        self._logger = logging.getLogger(__name__)

        if not account_name:
            raise ValueError("account_name must not be empty")

        credential = DefaultAzureCredential()
        self._client = BlobServiceClient(
            f"https://{account_name}.blob.core.windows.net", credential
        )
        self._logger.info(
            f"StorageHelper initialized for Azure Blob Storage account '{account_name}'"
        )

    def get_metadata_files(self, container_name) -> List[MetadataFile]:
        """
        Gets the metadata files from the storage account.

        Parameters
        ----------
        container_name (str): name of the container.

        Returns
        -------
        List[MetadataFile]
            List of metadata files.
        """
        try:
            self._logger.info("Retrieving metadata files from storage account...")
            self._logger.info(
                f"Searching container {container_name} for metadata files"
            )
            container_client = self._client.get_container_client(container_name)
            prefix = "_meta/"
            blobs = container_client.list_blobs(prefix)
            metadata_files = []
            for blob in blobs:
                if str(blob["name"]).endswith(".json"):
                    self._logger.info(f"Found metadata file: {blob['name']}")
                    metadata_json = self._download_blob(container_name, blob["name"])
                    metadata = MetadataFile(
                        container=container_name, metadata_json=metadata_json
                    )
                    metadata_files.append(metadata)
            self._logger.info(f"Found {len(metadata_files)} metadata files.")
            return metadata_files
        except Exception as e:
            self._logger.error(f"Error: {e}")
            return []

    def _download_blob(self, container_name: str, blob_name: str) -> Union[str, None]:
        """
        Downloads the content of a blob from the given container.

        Parameters:
            container_name (str): name of the container where the blob is located.
            blob_name (str): name of the blob to download.

        Returns:
            Union[str, None]: content of the blob as a string if successful, else None.
        """
        try:
            self._logger.info(f"Downloading blob: {blob_name}")
            container = self._client.get_container_client(container_name)
            blob = container.get_blob_client(blob_name)
            blob_data = blob.download_blob().readall()
            return blob_data.decode("utf-8")  # type: ignore
        except Exception as e:
            self._logger.error(
                f"Error downloading blob '{blob_name}'"
                f" from container '{container_name}': {e}"
            )
            return None
