"""
Purview Catalog helper module
"""
import logging
from typing import Any, Union

from azure.core.exceptions import HttpResponseError

from ..config import Configuration
from .clients import ClientHelper

JSONType = Any


class CatalogHelper:
    """
    Catalog helper functions
    """

    def __init__(self, configuration: Configuration):
        self._configuration = configuration
        self.logger = logging.getLogger(__name__)
        purviewhelper = ClientHelper(account_name=configuration.purview_account_name)
        self._catalog_client = purviewhelper.get_catalog_client()

    def get_synapse_table_fully_qualified_name(
        self, server_name: str, database_name: str, schema_name: str, table_name: str
    ) -> str:

        """
        Get the fully qualified name of a table given its attributes
        """
        return f"mssql://{server_name}/{database_name}/{schema_name}/{table_name}"

    def get_asset_by_fully_qualified_name(
        self, qualified_name: str, type_name: str
    ) -> Union[JSONType, None]:
        """
        Gets an asset from the catalog using its fully qualified name
        """
        try:
            entity = self._catalog_client.entity.get_by_unique_attributes(
                type_name=type_name, attr_qualified_name=qualified_name
            )
            return entity
        except (ValueError, HttpResponseError) as ex:
            self.logger.error(ex)
            return None

    def get_entity_id_by_fully_qualified_name(
        self, qualified_name: str, type_name: str
    ) -> Union[str, None]:

        """
        Get the entity id from its fully qualified name in Purview
        """
        try:
            entity = (
                self._catalog_client.entity.get_by_unique_attributes(  # type: ignore
                    type_name=type_name,
                    attr_qualified_name=qualified_name,
                )
            )
            return entity.get("entity", {}).get("guid")
        except (ValueError, HttpResponseError) as ex:
            self.logger.error(ex)
            return None

    def get_entity_id_from_asset(self, asset: Any) -> Union[str, None]:
        """Extracts the entity id from a purview catalog asset"""
        try:
            return asset.get("entity", {}).get("guid")
        except ValueError as ex:
            self.logger.error(ex)
            return None

    def set_attribute(self, entity_id: str, attribute_name: str, attribute_value: Any):
        """
        Update entity attribute value (e.g. description, any managed attribute, etc)
        """
        try:
            response = (
                self._catalog_client.entity.partial_update_entity_attribute_by_guid(
                    guid=entity_id, body=attribute_value, name=attribute_name
                )
            )
            self.logger.info(response)
            return response

        except (ValueError, HttpResponseError) as ex:
            self.logger.error(ex)

    def get_by_guid(self, guid: str):
        """
        Get an entity by guid
        """
        try:
            response = self._catalog_client.entity.get_by_guid(guid)  # type: ignore
            return response

        except (ValueError, HttpResponseError) as ex:
            self.logger.error(ex)

    def get_all_columns_per_entity(self, entity_id: str) -> dict[str, str] or None:
        """
        Get a dictionary with id and name of all the columns of the provided entity
        """
        columns = {}
        entity = self.get_by_guid(entity_id)
        if entity is None:
            return None

        entity_columns = (
            entity.get("entity", {})
            .get("relationshipAttributes", {})
            .get("columns", [])
        )

        for column in entity_columns:
            try:
                columns[column["guid"]] = column["displayText"]
            except KeyError as ex:
                self.logger.error(ex)
                continue

        return columns
