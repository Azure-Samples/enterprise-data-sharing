import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from azure.core.exceptions import HttpResponseError, ResourceNotFoundError

from src.helpers.config import Configuration
from src.helpers.keyvault.client import ClientHelper
from src.helpers.keyvault.data_security_file import DataSecurityFile, Rule


class TestKeyVaultHelper(unittest.TestCase):
    key_vault_helper: ClientHelper

    def get_helper(self):
        test_dir = Path(__file__).parent
        test_config_file = f"{test_dir}/.env.test"
        config = Configuration(test_config_file)
        self.helper = ClientHelper(config)
        return self.helper

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_get_data_security_file(self, mock_secret_client):
        data_security_file = DataSecurityFile(
            security_groups=["s1", "s2"],
            rules=[Rule(security_group="s1", constraints={"gdpr_zone": "red"})],
        )
        key_vault_helper = self.get_helper()
        key_vault_helper._client = mock_secret_client
        key_vault_helper.get_secret_versions = MagicMock(return_value=3)
        key_vault_helper.get_secret = MagicMock(return_value="any-secret")
        key_vault_helper.parse_json = MagicMock(return_value=data_security_file)
        key_vault_helper.validate_data_security_file = MagicMock(return_value=True)

        result = key_vault_helper.get_data_security_file("secret-name")

        self.assertEqual(result, data_security_file)

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_get_data_security_file_when_secret_versions_are_less_than_two(
        self, mock_secret_client
    ):
        key_vault_helper = self.get_helper()
        key_vault_helper._client = mock_secret_client
        key_vault_helper.get_secret_versions = MagicMock(return_value=1)

        result = key_vault_helper.get_data_security_file("secret-name")

        self.assertIsNone(result)

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_get_data_security_file_when_json_is_invalid(self, mock_secret_client):
        key_vault_helper = self.get_helper()
        key_vault_helper._client = mock_secret_client
        key_vault_helper.get_secret_versions = MagicMock(return_value=3)
        key_vault_helper.get_secret = MagicMock(return_value="any-secret")
        key_vault_helper.parse_json = MagicMock(return_value=None)

        result = key_vault_helper.get_data_security_file("secret-name")

        self.assertIsNone(result)

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_get_data_security_file_when_validation_of_security_file_fails(
        self, mock_secret_client
    ):
        key_vault_helper = self.get_helper()
        key_vault_helper._client = mock_secret_client
        key_vault_helper.get_secret_versions = MagicMock(return_value=3)
        key_vault_helper.get_secret = MagicMock(return_value="any-secret")
        key_vault_helper.parse_json = MagicMock(return_value="any-value")
        key_vault_helper.validate_data_security_file = MagicMock(return_value=False)

        result = key_vault_helper.get_data_security_file("secret-name")

        self.assertIsNone(result)

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_get_secret_versions(self, mock_secret_client):
        key_vault_helper = self.get_helper()
        key_vault_helper._client = mock_secret_client
        mock_secret_client.list_properties_of_secret_versions.return_value = {"1", "2"}

        result = key_vault_helper.get_secret_versions("secret-name")

        self.assertEqual(result, 2)

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_get_secret_versions_when_no_secret_available(self, mock_secret_client):
        key_vault_helper = self.get_helper()
        key_vault_helper._client = mock_secret_client

        result = key_vault_helper.get_secret_versions("secret-name")

        self.assertEqual(result, 0)

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_get_secret(self, mock_secret_client):
        key_vault_helper = self.get_helper()
        key_vault_helper._client = mock_secret_client
        mock_secret_client.get_secret.return_value.value = "secret_value"

        result = key_vault_helper.get_secret("secret-name")

        self.assertEqual(result, "secret_value")

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_get_secret_when_no_secret_available(self, mock_secret_client):
        key_vault_helper = self.get_helper()
        key_vault_helper._client = mock_secret_client
        mock_secret_client.get_secret.side_effect = ResourceNotFoundError()

        result = key_vault_helper.get_secret("secret-name")

        self.assertIsNone(result)

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_parse_json(self, mock_secret_client):
        key_vault_helper = self.get_helper()
        secret_value = '{ "security_groups": ["s1", "s2"], "rules": [{"constraints": {"gdpr_zone": "red"}, "security_group": "s1"}] }'

        result = key_vault_helper.parse_json(secret_value)

        self.assertEqual(
            result,
            DataSecurityFile(
                security_groups=["s1", "s2"],
                rules=[Rule(security_group="s1", constraints={"gdpr_zone": "red"})],
            ),
        )

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_parse_json_when_format_is_invalid(self, mock_secret_client):
        key_vault_helper = self.get_helper()
        secret_value = '{ "security_groups": ["s1", "s2"], "rules": [{"constraints": }, "security_group": "s1"}], }'

        result = key_vault_helper.parse_json(secret_value)

        self.assertIsNone(result)

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_validate_security_file(self, mock_secret_client):
        key_vault_helper = self.get_helper()
        data_security_file = DataSecurityFile(
            security_groups=["s1", "s2"],
            rules=[Rule(security_group="s1", constraints={"gdpr_zone": "red"})],
        )

        result = key_vault_helper.validate_data_security_file(data_security_file)

        self.assertTrue(result)

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_validate_security_file_when_no_security_groups_provided(
        self, mock_secret_client
    ):
        key_vault_helper = self.get_helper()
        data_security_file = DataSecurityFile(
            security_groups=[],
            rules=[Rule(security_group="s1", constraints={"gdpr_zone": "red"})],
        )

        result = key_vault_helper.validate_data_security_file(data_security_file)

        self.assertFalse(result)

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_validate_security_file_when_no_rules_provided(self, mock_secret_client):
        key_vault_helper = self.get_helper()
        data_security_file = DataSecurityFile(
            security_groups=["s1", "s2"],
            rules=[],
        )

        result = key_vault_helper.validate_data_security_file(data_security_file)

        self.assertFalse(result)

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_validate_security_file_when_security_groups_in_rules_are_invalid(
        self, mock_secret_client
    ):
        key_vault_helper = self.get_helper()
        data_security_file = DataSecurityFile(
            security_groups=["s1", "s2"],
            rules=[Rule(security_group="s3", constraints={"gdpr_zone": "red"})],
        )

        result = key_vault_helper.validate_data_security_file(data_security_file)

        self.assertFalse(result)

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_check_secret(self, mock_secret_client):
        key_vault_helper = self.get_helper()
        key_vault_helper._client = mock_secret_client
        mock_secret_client.get_secret.return_value = "secret_value"

        result = key_vault_helper.check_secret("secret-name")

        self.assertTrue(result)

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_check_secret_when_no_secret_available(self, mock_secret_client):
        key_vault_helper = self.get_helper()
        key_vault_helper._client = mock_secret_client
        mock_secret_client.get_secret.side_effect = ResourceNotFoundError()

        result = key_vault_helper.check_secret("secret-name")

        self.assertFalse(result)

    @patch("src.helpers.keyvault.client.SecretClient")
    def test_check_secret_when_exception_occurs(self, mock_secret_client):
        key_vault_helper = self.get_helper()
        key_vault_helper._client = mock_secret_client
        mock_secret_client.get_secret.side_effect = HttpResponseError()

        with self.assertRaises(HttpResponseError):
            key_vault_helper.check_secret("secret-name")
