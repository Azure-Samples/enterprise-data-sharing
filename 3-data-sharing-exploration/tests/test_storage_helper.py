import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from src.helpers.config import Configuration
from src.helpers.storage import MetadataFile, StorageHelper


class TestStorageHelper(unittest.TestCase):
    helper: StorageHelper

    def get_helper(self):
        test_dir = Path(__file__).parent
        test_config_file = f"{test_dir}/.env.test"
        config = Configuration(test_config_file)
        self.helper = StorageHelper(config.storage_account_name)
        return self.helper

    @patch("src.helpers.storage.BlobServiceClient")
    @patch("src.helpers.storage.DefaultAzureCredential")
    def test_get_metadata_files_should_return_metadata_files(
        self, mock_azure_creds, mock_storage_client
    ):
        storage_helper = self.get_helper()
        storage_helper._client = mock_storage_client
        storage_helper._download_blob = MagicMock(return_value={"name": "MetadataFile"})
        container_client = MagicMock()
        mock_storage_client.get_container_client.return_value = container_client
        container_client.list_blobs.return_value = [
            {"name": "A.json"},
            {"name": "B"},
        ]

        metadata_files = storage_helper.get_metadata_files("container1")

        self.assertEqual(
            [
                MetadataFile(
                    container="container1", metadata_json={"name": "MetadataFile"}
                )
            ],
            metadata_files,
        )


if __name__ == "__main__":
    unittest.main()
