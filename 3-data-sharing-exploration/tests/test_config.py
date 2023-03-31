import os
import unittest

from src.helpers.config import Configuration


class TestConfiguration(unittest.TestCase):
    def test_purview_account_name(self):
        config = Configuration()
        os.environ["PURVIEW_ACCOUNT_NAME"] = "test_account_name"
        self.assertEqual(config.purview_account_name, "test_account_name")

    def test_storage_account_name(self):
        config = Configuration()
        os.environ["STORAGE_ACCOUNT_NAME"] = "test_account_name"
        self.assertEqual(config.storage_account_name, "test_account_name")

    def test_configuration_file_not_found(self):
        config = Configuration(configuration_file="non_existent.env")
        self.assertEqual(config.purview_account_name, "")
        self.assertEqual(config.storage_account_name, "")


if __name__ == "__main__":
    unittest.main()
