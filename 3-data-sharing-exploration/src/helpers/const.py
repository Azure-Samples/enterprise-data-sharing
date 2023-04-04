"""
Const
-----
This module contains static string, that are used for accessing environment
and configuration variables
"""


class _Const(object):
    __slots__ = ()

    PURVIEW_SYNAPSE_SQL_VIEW_DATA_TYPE = "azure_synapse_serverless_sql_view"
    PURVIEW_SYNAPSE_SQL_TABLE_DATA_TYPE = "azure_synapse_serverless_sql_table"
    PURVIEW_SYNAPSE_SQL_VIEW_COLUMN_DATA_TYPE = (
        "azure_synapse_serverless_sql_view_column"
    )
    PURVIEW_SYNAPSE_SQL_SCHEMA_DATA_TYPE = "azure_synapse_serverless_sql_schema"
    PURVIEW_SYNAPSE_SQL_DB_DATA_TYPE = "azure_synapse_serverless_sql_db"


CONST = _Const()
