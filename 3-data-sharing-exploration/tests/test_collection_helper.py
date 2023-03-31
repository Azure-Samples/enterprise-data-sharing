import unittest
from unittest.mock import MagicMock

from src.helpers.config import Configuration
from src.helpers.purview.collections import CollectionHelper


class TestCollectionHelper(unittest.TestCase):
    def setUp(self):
        # create a mock Configuration object
        self.config = Configuration()
        self.config.purview_account_name = "mock_account_name"
        self.config.purview_collection_name = "mock_collection_name"

    def get_collection_object(
        self,
        collectionName: str,
        parentCollectionName: str = "",
    ):
        if parentCollectionName and parentCollectionName != "":
            collection = {
                "friendlyName": collectionName,
                "parentCollection": {"referenceName": parentCollectionName},
            }
        else:
            collection = {"friendlyName": collectionName}
        return collection

    def test_get_collection(self):
        # setup
        collection_helper = CollectionHelper(self.config)
        mock_get_collection = MagicMock()
        mock_get_collection.return_value = self.get_collection_object(
            collectionName=self.config._purview_collection_name,
            parentCollectionName="root_collection",
        )
        collection_helper._account_client.collections.get_collection = (
            mock_get_collection
        )

        collection = collection_helper.get_collection(
            self.config.purview_collection_name
        )

        mock_get_collection.assert_called_with(
            collection_name=self.config.purview_collection_name
        )
        self.assertIsNotNone(collection)
        self.assertEqual(
            collection["friendlyName"], self.config.purview_collection_name
        )

    def test_create_collection(self):
        # setup
        collection_helper = CollectionHelper(self.config)

        expected_collection = self.get_collection_object(
            collectionName=self.config._purview_collection_name
        )
        expected_name = self.config._purview_collection_name.replace("_", "-")
        mock_create_collection = MagicMock()
        mock_create_collection.return_value = expected_collection
        collection_helper._account_client.collections.create_or_update_collection = (
            mock_create_collection
        )

        collection = collection_helper.create_collection(
            self.config.purview_collection_name
        )

        mock_create_collection.assert_called_with(
            collection_name=expected_name,
            collection=expected_collection,
        )
        self.assertIsNotNone(collection)
        self.assertEqual(
            collection["friendlyName"], self.config.purview_collection_name
        )

    def test_delete_collection(self):
        # setup
        collection_helper = CollectionHelper(self.config)
        mock_delete_collection = MagicMock()
        mock_delete_collection.return_value = None
        collection_helper._account_client.collections.delete_collection = (
            mock_delete_collection
        )
        result = collection_helper.delete_collection(
            self.config.purview_collection_name
        )
        mock_delete_collection.assert_called_with(
            collection_name=self.config.purview_collection_name,
        )
        self.assertIsNone(result)


if __name__ == "__main__":
    unittest.main()
