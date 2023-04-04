import logging
from typing import Union

from azure.core.exceptions import HttpResponseError, ResourceNotFoundError
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

from ..config import Configuration
from .data_security_file import DataSecurityFile


class ClientHelper:
    """
    Class with helper functions for KeyVault
    """

    def __init__(self, config: Configuration):
        self._config = config
        self._logger = logging.getLogger(__name__)

        self._client = SecretClient(
            credential=DefaultAzureCredential(),
            vault_url=f"https://{config.keyvault_name}.vault.azure.net/",
        )

    def get_data_security_file(
        self, data_security_file_name: str
    ) -> Union[DataSecurityFile, None]:

        """
        Retrieves data security file from keyvault,
        performs validation on file,
        maps the file to object and return
        """
        security_json = self.get_secret(data_security_file_name)
        if not security_json:
            self._logger.error(f"Secret {data_security_file_name} not found!")
            return None

        versions = self.get_secret_versions(data_security_file_name)
        if versions < 2:
            self._logger.warning("Data Security File should have at least 2 versions")
            return None

        data_security_file = self.parse_json(security_json)
        if data_security_file and self.validate_data_security_file(data_security_file):
            return data_security_file

        return None

    def get_secret_versions(self, data_security_file_name: str) -> int:
        """
        Get number of versions exists for secret.
        """
        versions = self._client.list_properties_of_secret_versions(
            name=data_security_file_name
        )
        return sum(1 for _ in versions)

    def check_secret(self, secret_name: str) -> bool:
        """Check secret exists

        Args:
            secret_name (str): name of the secret

        Returns:
            bool: Returns True if secret exists, False otherwise

        :raises:
            :class:`~azure.core.exceptions.HttpResponseError`
            if KeyVault cannot be accessed
        """
        try:
            secret = self._client.get_secret(name=secret_name)
            if secret:
                return True
            else:
                return False
        except ResourceNotFoundError as ex:
            self._logger.error(f"Unable to find secret in key vault, {ex}")
            return False
        except HttpResponseError as ex:
            self._logger.error(f"Error connecting to Keyvault, {ex}")
            raise ex

    def get_secret(self, secret_name: str) -> Union[str, None]:
        """
        Get secret from key vault.
        """
        try:
            return self._client.get_secret(name=secret_name).value
        except (ResourceNotFoundError, HttpResponseError) as ex:
            self._logger.error(f"Unable to retrieve secret from key vault, {ex}")
            return None

    def parse_json(self, security_json) -> Union[DataSecurityFile, None]:
        """
        Converts json to DataSecurityFile object.
        """
        try:
            return DataSecurityFile.from_json(security_json)  # type:ignore
        except ValueError as e:
            self._logger.error(f"Invalid json format, {e}")
            return None

    def validate_data_security_file(self, data_security_file) -> bool:
        """
        Validates if security file is valid by checking:
        1. Has at least one security groups provided
        2. Has at least one rule provided
        3. Rules contain security group only from list of security groups
        """
        if not data_security_file.security_groups or not data_security_file.rules:
            self._logger.error("Either security groups or rules are missing.")
            return False
        for rule in data_security_file.rules:
            if rule.security_group not in data_security_file.security_groups:
                self._logger.error(f"Invalid security group provided in {rule}")
                return False
        return True
