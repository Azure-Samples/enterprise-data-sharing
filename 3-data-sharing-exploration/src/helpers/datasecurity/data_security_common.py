import logging

from ..const import CONST
from ..config import Configuration
from ..metadata import Metadata, Table
from ..purview.catalog import CatalogHelper
from ..purview.managed_attributes import ManagedAttributesHelper


class DataSecurityCommon:
    """Contains general methods for managing data security"""

    def __init__(self, configuration: Configuration):
        self.logger = logging.getLogger(__name__)
        self._configuration = configuration
        self._catalog_helper = CatalogHelper(configuration)
        self._m_attribute_helper = ManagedAttributesHelper(configuration)
        self.logger.info("DataSecurityCommon initialized")

    def get_data_security_attribute(self) -> str:
        """
        Get data security attribute from env variable
        """
        return self._configuration.data_security_attribute

    def get_security_for_views(
        self,
        metadata_as_json: str,
        m_attribute_name: str,
        m_attribute_group: str,
    ) -> dict:
        """
        Get the values of the managed attribute used for security in Purview
        for all the views in the metadata file.

        Returns
        -------------
        dict ( str: [ str | dict ] ) : (view_name, assigned_security_group(s))
        """

        # synapse views scanned in purview are used as source of truth for security

        self.logger.info("Get Security Groups assigned to Views from Purview")

        metadata = Metadata.from_json(metadata_as_json)  # type: ignore
        synapse_workspace = self._configuration.synapse_workspace_name
        synapse_server = f"{synapse_workspace}-ondemand.sql.azuresynapse.net"
        database_name = self._configuration.synapse_database
        path = metadata.path
        schema_path = f"{path}_{self._configuration.synapse_database_schema}"

        results = dict()

        for table in metadata.tables:
            table_qualified_name = (
                self._catalog_helper.get_synapse_table_fully_qualified_name(
                    server_name=synapse_server,
                    database_name=database_name,
                    schema_name=schema_path,
                    table_name=table.name,
                )
            )

            table_guid = self._catalog_helper.get_entity_id_by_fully_qualified_name(
                qualified_name=table_qualified_name,
                type_name=CONST.PURVIEW_SYNAPSE_SQL_VIEW_DATA_TYPE,
            )
            if table_guid is None:
                self.logger.error(
                    f"{table.name} can't be found, security info can't be retrieved."
                )
                continue

            security_value = self._m_attribute_helper.get_m_attribute_value(
                entity_id=table_guid,
                m_attribute_group=m_attribute_group,
                m_attribute_name=m_attribute_name,
            )

            results[table.name] = security_value

            # if security is set at table level, then we ignore columns
            if security_value != "Not Assigned":
                continue

            column_security = self.get_security_for_view_columns(
                m_attribute_name,
                m_attribute_group,
                table,
                table_qualified_name,
            )

            results[table.name] = column_security

        return results

    def get_security_for_view_columns(
        self,
        m_attribute_name: str,
        m_attribute_group: str,
        table: Table,
        table_qualified_name: str,
    ) -> dict:
        """
        Get Security managed attribute value for all the table columns
        """
        security_values = {}
        for column in table.columns:
            column_qualified_name = table_qualified_name + f"#{column.name}"
            column_guid = self._catalog_helper.get_entity_id_by_fully_qualified_name(
                qualified_name=column_qualified_name,
                type_name=CONST.PURVIEW_SYNAPSE_SQL_VIEW_COLUMN_DATA_TYPE,
            )
            if column_guid is None:
                self.logger.error(
                    f"{column.name} can't be found in Purview. "
                    "Security info can't be retrieved."
                )
                continue

            column_security_value = self._m_attribute_helper.get_m_attribute_value(
                entity_id=column_guid,
                m_attribute_group=m_attribute_group,
                m_attribute_name=m_attribute_name,
            )

            security_values.update({column.name: column_security_value})
        return security_values
