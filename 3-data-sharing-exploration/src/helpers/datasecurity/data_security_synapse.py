import logging
from dataclasses import dataclass
from typing import Dict, List

from ..config import Configuration
from ..const import CONST
from ..keyvault.data_security_file import DataSecurityFile
from ..purview.catalog import CatalogHelper
from ..purview.collections import CollectionHelper
from ..purview.managed_attributes import ManagedAttributesHelper
from ..sql import SqlHelper


@dataclass
class UserDbPermission:
    """
    Represents a single permission granted to a user over a table, view or column
    """

    table: str
    column: str
    permission: str
    state: str


class DataSecuritySynapse:
    """Contains methods for managing data security in storage"""

    def __init__(self, configuration: Configuration):
        self.logger = logging.getLogger(__name__)
        self._configuration = configuration
        self._managed_attribute_helper = ManagedAttributesHelper(
            configuration=self._configuration
        )
        self._sql_helper = SqlHelper(configuration=self._configuration)

    def assign_managed_attribute_for_security(
        self, security_attribute: str = None, security_file: DataSecurityFile = None
    ) -> Dict[str, str]:
        """
        Apply security access to Synapse assets based on the sensitivity.

        Parameters
        ----------
        security_attribute: str = None
            If None, then the security attribute to be applied is evaluated based on
            the data security file

        security_file: DataSecurityFile = None
            If None, then the other parameter security attribute is applied
        """
        # asset types to apply security
        types = [
            CONST.PURVIEW_SYNAPSE_SQL_VIEW_DATA_TYPE,
            CONST.PURVIEW_SYNAPSE_SQL_TABLE_DATA_TYPE,
        ]

        collection_name = self._configuration.purview_collection_name
        collection_helper = CollectionHelper(self._configuration)
        entities = collection_helper.get_collection_assets_by_types(
            collection_name=collection_name, data_types=types, include_child=True
        )

        if not entities:
            self._logger.error(
                f"No entities found in Purview collection {collection_name} "
                "and subcollections for types: {types}",
            )
            return {}

        managed_attribute_group = self._configuration.security_managed_attribute_group
        security_group_managed_attribute = (
            self._configuration.security_managed_attribute_name
        )
        self._managed_attribute_helper.add_m_attribute_to_attribute_group(
            managed_attribute_group, security_group_managed_attribute
        )

        assignments = {}
        for entity in entities:

            print(
                "Assigning security group managed attribute to "
                f"{entity['qualifiedName']}"
            )
            security_attribute_value = self.assign_security_attribute_to_entity(
                entity_id=entity["id"],
                security_attribute=security_attribute,
                managed_attribute_group=managed_attribute_group,
                security_group_managed_attribute=security_group_managed_attribute,
                security_file=security_file,
            )

            assignments[entity["name"]] = security_attribute_value

            # for views, we also need to assign security attributes to each column
            if entity["entityType"] == CONST.PURVIEW_SYNAPSE_SQL_VIEW_DATA_TYPE:
                column_assignments = self.assign_security_attribute_to_columns(
                    entity_id=entity["id"],
                    security_attribute_name=security_attribute,
                    managed_attribute_group=managed_attribute_group,
                    security_group_managed_attribute=security_group_managed_attribute,
                    security_file=security_file,
                )
                for column_name, column_security_value in column_assignments.items():
                    column_index = f"{entity['name']}_{column_name}"
                    assignments[column_index] = column_security_value

        # if no security attribute could be assigned,
        # then suggest to check constraints and managed attributes
        if all(x is None for x in assignments.values()):
            self._logger.error(
                f"{security_attribute} never assigned. Please verify if the "
                "constraints used in the data security file correspond to managed "
                "attributes in Purview."
            )
        return assignments

    def assign_security_attribute_to_entity(
        self,
        entity_id: str,
        security_attribute: str,
        managed_attribute_group: str,
        security_group_managed_attribute: str,
        security_file: DataSecurityFile,
    ) -> str or None:
        """
        Identify the Security Group associated to this entity
        and assign the value in Purview managed attribute
        """
        security = "Not Assigned"

        if security_file is None:
            managed_attribute_sensitivity = (
                self._managed_attribute_helper.get_m_attribute_value(
                    security_attribute, managed_attribute_group, entity_id
                )
            )

            if managed_attribute_sensitivity:
                if managed_attribute_sensitivity == "low":
                    security = self._configuration.data_security_group_low
                elif managed_attribute_sensitivity == "medium":
                    security = self._configuration.data_security_group_medium
                elif managed_attribute_sensitivity == "high":
                    security = self._configuration.data_security_group_high
        else:
            attributes = self._managed_attribute_helper.get_all_m_attributes_per_group(
                entity_id=entity_id, m_attribute_group=managed_attribute_group
            )
            if attributes:
                attributes_lower = dict(
                    (k.replace(" ", "_").lower(), v.lower())
                    for k, v in attributes.items()
                )
                # for each rule in the dataSecurityFile - in order
                for rule in security_file.rules:
                    constraints_lower = dict(
                        (k.lower(), v.lower()) for k, v in rule.constraints.items()
                    )
                    # check if constraints match to the managed attributes of the entity
                    result = constraints_lower.items() <= attributes_lower.items()
                    if result:
                        # assign the security group corresponding to the first match
                        self._managed_attribute_helper.update_m_attribute(
                            entity_id=entity_id,
                            m_attribute_group=managed_attribute_group,
                            m_attribute_name=security_group_managed_attribute,
                            m_attribute_value=rule.security_group,
                        )
                        return rule.security_group

        if security == "Not Assigned":
            self.logger.info(
                f"{security_group_managed_attribute} cannot be assigned to {entity_id} "
                "because there is no rule matching with this entity"
            )

        self._managed_attribute_helper.update_m_attribute(
            entity_id=entity_id,
            m_attribute_group=managed_attribute_group,
            m_attribute_name=security_group_managed_attribute,
            m_attribute_value=security,
        )

        return security

    def assign_security_attribute_to_columns(
        self,
        entity_id: str,
        security_attribute_name: str,
        managed_attribute_group: str,
        security_group_managed_attribute: str,
        security_file: DataSecurityFile,
    ) -> Dict:
        """
        Assign security attribute to all columns of this entity
        """
        catalog_helper = CatalogHelper(self._configuration)
        columns = catalog_helper.get_all_columns_per_entity(entity_id)
        assignments = dict()
        if columns:
            for column_id in columns.keys():
                assignments[
                    columns[column_id]
                ] = self.assign_security_attribute_to_entity(
                    security_attribute=security_attribute_name,
                    entity_id=column_id,
                    managed_attribute_group=managed_attribute_group,
                    security_group_managed_attribute=security_group_managed_attribute,
                    security_file=security_file,
                )
        return assignments

    def apply_security_to_synpase_assets(
        self,
        assigned_security_groups: dict,
        path: str,
        security_file: DataSecurityFile = None,
    ):
        """
        Create SQL grant statement and apply security to syapse assets.
        """
        schema = f"{path}_{self._configuration.synapse_database_schema}"
        self._cleanup_database_users(security_file)

        for assigned_security_group in assigned_security_groups:
            assigned_security_group_value = assigned_security_groups.get(
                assigned_security_group
            )
            if isinstance(assigned_security_group_value, dict):
                for value in assigned_security_group_value:
                    securtiy_group = assigned_security_group_value[value]
                    if securtiy_group != "Not Assigned":
                        sqlGrantStatement = (
                            f"GRANT SELECT ON {schema}.{assigned_security_group}({value}) TO "
                            f"{securtiy_group}"
                        )
                        self._sql_helper.execute_sql(sql=sqlGrantStatement)
            else:
                securtiy_group = assigned_security_groups[assigned_security_group]
                if securtiy_group != "Not Assigned":
                    sqlGrantStatement = (
                        f"GRANT SELECT ON {schema}.{assigned_security_group} TO "
                        f"{securtiy_group}"
                    )
                    self._sql_helper.execute_sql(sql=sqlGrantStatement)
        return None

    def _cleanup_database_users(self, security_file: DataSecurityFile = None):

        """
        Drops and recreates all db useres associated to AD Security Groups

        Parameters
        ----------
        security_file: DataSecurityFile = None
            If None, then the basic security is applied and the 3 Security Groups
            are gathered from config.
        """
        users = [
            self._configuration.data_security_group_low,
            self._configuration.data_security_group_medium,
            self._configuration.data_security_group_high,
        ]

        if security_file:
            users = security_file.security_groups

        for user in users:
            self._sql_helper.drop_db_user(user)
            self._sql_helper.create_db_user(user)

        return None

    def _list_db_permissions_for_user_in_synapse(
        self, db_user: str
    ) -> Dict[str, List[UserDbPermission]]:
        """
        Checks the active permissions a user in a Synapse database

            Parameters:
                    db_user (str): the db_user name

            Returns:
                    result (bool): True if the user has an active GRANT statement, False otherwise
        """
        try:
            # get user id
            sql_statement = f"SELECT principal_id FROM sys.database_principals WHERE [name] = '{db_user}'"
            user_id = self._sql_helper.execute_sql_result(sql=sql_statement)[0][0]

            sql_statement = (
                f"SELECT sys.views.name AS TableName, permission_name AS PermissionName, state_desc as State "
                f"FROM sys.database_permissions "
                f"JOIN sys.views ON sys.database_permissions.major_id = sys.views.object_id "
                f"WHERE grantee_principal_id = {user_id}"
            )

            result = self._sql_helper.execute_sql_result(sql=sql_statement)

            table_permissions = [
                UserDbPermission(table=x[0], column="", permission=x[1], state=x[2])
                for x in result
            ]

            sql_statement = (
                f"SELECT sys.views.name AS TableName, sys.columns.name as ColumnName, permission_name AS PermissionName, state_desc as State "
                f"FROM sys.database_permissions "
                f"JOIN sys.views ON sys.database_permissions.major_id = sys.views.object_id "
                f"JOIN sys.columns ON sys.database_permissions.major_id = sys.columns.object_id "
                f"AND sys.database_permissions.minor_id = sys.columns.column_id "
                f"WHERE grantee_principal_id = {user_id}"
            )

            result = self._sql_helper.execute_sql_result(sql=sql_statement)

            column_permissions = [
                UserDbPermission(table=x[0], column=x[1], permission=x[2], state=x[3])
                for x in result
            ]

            return {
                "table_permissions": table_permissions,
                "column_permissions": column_permissions,
            }

        except Exception as ex:
            self.logger.error(ex)
            return {"table_permissions": [], "column_permissions": []}
