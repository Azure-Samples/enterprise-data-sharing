from ..const import CONST


class AssetHelper:

    sql_types = [
        CONST.PURVIEW_SYNAPSE_SQL_VIEW_DATA_TYPE,
        CONST.PURVIEW_SYNAPSE_SQL_TABLE_DATA_TYPE,
        CONST.PURVIEW_SYNAPSE_SQL_SCHEMA_DATA_TYPE,
    ]

    @staticmethod
    def is_sql_asset(asset) -> bool:
        asset_type = asset["entityType"]
        return asset_type in AssetHelper.sql_types

    @staticmethod
    def get_database_schema(asset):
        """
        Returns a database schema from a sql asset in purview
        """
        if AssetHelper.is_sql_asset(asset):
            qualified_name = asset["qualifiedName"]

            qualified_name_parts = qualified_name.split("/")

            if len(qualified_name_parts) > 4:
                schema_name = qualified_name_parts[4]
                return schema_name

        return None
