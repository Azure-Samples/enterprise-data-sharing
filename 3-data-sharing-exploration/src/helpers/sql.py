import logging
import struct
from itertools import chain, repeat
from typing import List, Tuple

import pyodbc
from azure.identity import AzureCliCredential

from .config import Configuration
from .metadata import Metadata


class SqlHelper:
    """Contains methods for interacting with Synapse"""

    _configuration: Configuration

    def __init__(
        self,
        configuration: Configuration,
        database: str = "",
        use_cli_credentials: bool = False,
    ):
        self._configuration = configuration
        self._cli_credentials = use_cli_credentials
        self._cursor = None
        if database != "":
            self._database = database
        else:
            self._database = configuration.synapse_database
        self._schema = None
        self.logger = logging.getLogger(__name__)
        self.logger.info("SqlHelper initialized.")

    def get_connection_cursor_az_cli_token(self):
        """
        Connects to SYNAPSE_DATABASE provided in the configuration using AZ CLI cred
        """

        driver = self._configuration.synapse_driver
        synapse_workspace = self._configuration.synapse_workspace_name
        synapse_server = f"{synapse_workspace}-ondemand.sql.azuresynapse.net"
        database_name = self._database
        credentials = AzureCliCredential()
        db_token = credentials.get_token("https://database.windows.net/.default")

        connectionstring = (
            f"Driver={driver};"
            f"Server=tcp:{synapse_server},1433;"
            f"Database={database_name};"
            "Encrypt=yes;"
            "TrustServerCertificate=no;"
            "Connection Timeout=30;"
        )
        self.logger.info(f"Connectionstring: {connectionstring}")

        try:
            token_bytes = db_token.token.encode()
            # Need to convert the token bytes into MS-Windows BSTR in little-endian
            # format. Link to the original issue and code:
            # https://github.com/mkleehammer/pyodbc/issues/228#issuecomment-496439697
            encoded_bytes = bytes(chain.from_iterable(zip(token_bytes, repeat(0))))
            tokenstruct = struct.pack("<i", len(encoded_bytes)) + encoded_bytes

            # connect by using the formatted token
            connection = pyodbc.connect(
                connectionstring, attrs_before={1256: tokenstruct}
            )
            connection.autocommit = True
            self._cursor = connection.cursor()
            return self._cursor

        except Exception as e:
            self.logger.error(e)
            raise e

    def get_connection_cursor(self):
        """
        Connects to SYNAPSE_DATABASE provided in the configuration
        """
        if self._cursor is not None:
            return self._cursor

        driver = self._configuration.synapse_driver
        synapse_workspace = self._configuration.synapse_workspace_name
        synapse_server = f"{synapse_workspace}-ondemand.sql.azuresynapse.net"
        database_name = self._database

        username = self._configuration.azure_client_id
        password = self._configuration.azure_client_secret

        connectionstring = (
            f"Driver={driver};"
            f"Server=tcp:{synapse_server},1433;"
            f"Database={database_name};"
            f"Uid={username};"
            f"Pwd={password};"
            "authentication=ActiveDirectoryServicePrincipal;"
            "Encrypt=yes;"
            "TrustServerCertificate=no;"
            "Connection Timeout=30;"
        )

        self.logger.info(f"Connectionstring: {connectionstring}")

        try:
            connection = pyodbc.connect(connectionstring)
            connection.autocommit = True
            self._cursor = connection.cursor()
            return self._cursor

        except Exception as e:
            self.logger.error(e)
            raise e

    def execute_sql_result(self, sql: str) -> list:
        """
        Executes a sql command on the database provided in the configuraiton
        and returns a list of results.

        Parameters:
        ----------
        sql: str
            the SQL statement to run
        """
        self.logger.info(f"Execute SQL-Command on {self._database}: {sql}")
        cursor = self.get_connection_cursor()
        if cursor is not None:
            cursor.execute(sql)
            result = []
            row = cursor.fetchone()
            while row:
                result.append(row)
                row = cursor.fetchone()

        return result

    def execute_sql(self, sql: str, use_cli_cred: bool = False):
        """
        Executes a sql command on the database provided in the configuraiton.

        Parameters:
        ----------
        sql : str
            the SQL statement to run

        use_cli_cred : bool = False
            Optional.
            Set as True if the method should use Azure CLI credentials
            instead of service principal's.
        """
        self.logger.info(f"Execute SQL-Command on {self._database}: {sql}")
        if use_cli_cred:
            cursor = self.get_connection_cursor_az_cli_token()
        else:
            cursor = self.get_connection_cursor()
        if cursor is not None:
            cursor.execute(sql)

        return cursor

    def create_external_data_source(
        self, container_name: str, path: str, schema: str
    ) -> str:
        """
        Create an External Data Source named: version_schema.

        Parameters:
        ----------
        container_name: str
            the container where the Delta Tables are located
        path: str
            the path to the Delta Tables
        schema: str
            the schema to be used in the external data source name
        """
        self.logger.info("Create external data source")

        source_storage_account = self._configuration.storage_account_name
        delta_tables_path = (
            f"https://{source_storage_account}.dfs.core.windows.net/"
            f"{container_name}/{path}/"
        )

        # Create the External Data Source, if it doesn't exist.
        external_data_source = f"{path}_{schema}"

        sql = (
            f"IF NOT EXISTS"
            "(SELECT * "
            "FROM sys.external_data_sources "
            f"WHERE name='{external_data_source}')"
            f"CREATE EXTERNAL DATA SOURCE {external_data_source} "
            "WITH ("
            f"      LOCATION = '{delta_tables_path}'"
            ")"
        )

        result = self.execute_sql(sql)
        if result is None:
            self.logger.error(
                f"External Data Source creation failed: {external_data_source}"
            )
            raise Exception("Error creating external data source")
        else:
            self.logger.info(f"External Data Source created: {external_data_source}")

        return external_data_source

    def create_or_update_view(
        self, external_data_source: str, version: str, folder_name: str, schema: str
    ):
        """
        Create or update a View based on a Delta Table.

        Parameters
        ----------
        external_data_source: str
            the external data source to use

        version: str
            the version to be used in the naming convention

        folder_name: str
            the folder containing the delta_log

        schema: str
            the schema name

        """

        # The data used in the sample has schema and table names embedded
        # in the folder name - e.g.: SalesLT_Customer
        if "_" in folder_name:
            view_name = folder_name.split("_")[1]
        else:
            view_name = folder_name

        # The full schema name is composed of version and schema
        full_schema_name = f"{version}_{schema}"
        # Check if the schema exists, and create it if it doesn't
        if self._schema != full_schema_name:
            self.create_schema(full_schema_name)

        name = view_name.lower().replace("_", "")

        sql = (
            f"CREATE OR ALTER VIEW {full_schema_name}.{view_name} "
            "AS SELECT * "
            "FROM "
            "    OPENROWSET("
            f"        BULK '{folder_name}',"
            f"        DATA_SOURCE = '{external_data_source}',"
            "        FORMAT = 'DELTA'"
            f"    ) {name}"
        )
        self.execute_sql(sql)

    def create_views_from_metadata(self, metadata_as_json: str, schema: str):
        """
        Create views for each table listed in the metadata file in input
        The views will be created on the database provided as configuration.

        Parameters
        ----------
        metadata_file : MetadataFile
            Metadata information provided as json string

        schema: str
            schema name to be used for the Views.
        """
        metadata = Metadata.from_json(metadata_as_json)  # type: ignore

        # Create External Data Source
        external_datasource_name = self.create_external_data_source(
            container_name=self._configuration.adls_container_name,
            path=metadata.path,
            schema=schema,
        )

        # Create Views (and schema) based on the metadata file
        for table in metadata.tables:
            self.logger.info(
                f"Creating view {table.name} on data source {external_datasource_name}"
            )

            table_name = f"{schema}_{table.name}"

            self.create_or_update_view(
                external_data_source=external_datasource_name,
                version=metadata.major_version_identifier,
                folder_name=table_name,
                schema=schema,
            )

    def create_schema(self, schema_name: str):
        """
        Create a schema on the default database provided as env variable

        Parameters
        ----------
        schema_name: str
            Name of the schema
        """
        sql = (
            f"IF NOT EXISTS(SELECT * FROM sys.schemas WHERE name='{schema_name}') "
            f"EXEC('CREATE SCHEMA {schema_name}');"
        )
        self.execute_sql(sql)
        self._schema = schema_name

    def list_views(self) -> List[str]:
        """
        Get all views in the database provided as configuration.

        Returns
        -------
        List[str]
            List of views in the database provided as config.
        """
        self.logger.info(f"Getting views for database {self._database}")
        sql_to_get_views = (
            "SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS"
        )
        sql_view_result: List[Tuple[str, str]] = self.execute_sql_result(
            sql_to_get_views
        )

        views: List[str] = [f"{view[0]}.{view[1]}" for view in sql_view_result]

        self.logger.debug(f"Views output from SQL Query: {views}")
        return views

    def drop_all_views(self):
        """
        Drop all views in the database provided as config.
        """
        self.logger.info(f"Dropping all views in database {self._database}")
        views = self.list_views()
        for view in views:
            sql = f"DROP VIEW {view}"
            self.execute_sql(sql)

        self.logger.debug("All Views dropped")
        return views

    def create_database(self, db_name: str, set_as_default_db: bool = True):
        """
        Create a database

        Parameters
        ----------
        db_name : str
            Name of the database

        set_as_default_db : bool = True
            Optional.
            Set as False if the new DB should be not used as default.
        """
        sql = (
            f"IF NOT EXISTS(SELECT * FROM sys.databases WHERE name='{db_name}') "
            "BEGIN "
            f"   CREATE DATABASE [{db_name}] "
            "END"
        )
        self.execute_sql(sql, self._cli_credentials)
        if set_as_default_db is True:
            self._database = db_name

    def drop_database(self, db_name: str):
        """
        Deletes a database

        Parameters
        ----------
        db_name : str
            Name of the database
        """
        sql = (
            f"IF EXISTS(SELECT * FROM sys.databases WHERE name='{db_name}') "
            "BEGIN "
            f"   DROP DATABASE {db_name} "
            "END"
        )
        self.execute_sql(sql)
        if self._database == db_name:
            self._database = None
            self.logger.warning(
                "Default database has been dropped. Use 'create_database' to reset it."
            )

    def drop_db_user(self, db_user: str):
        try:
            sql = f"DROP USER IF EXISTS {db_user}"
            self.execute_sql(sql)
            self.logger.info(f"Dropped user {db_user} ")
        except Exception as ex:
            self.logger.error(ex)

    def create_login(self, login_user: str):
        """
        Create login from external provider.
        This method must run using Azure CLI Credentials because the service principal
        does not have permissions to crate logins.

        Parameters
        ----------
        login: str
            AD User/Group to create the login
        """
        sql = (
            "IF NOT EXISTS"
            f"(SELECT * FROM sys.server_principals WHERE name='{login_user}') "
            "BEGIN "
            f"   CREATE LOGIN [{login_user}] FROM EXTERNAL PROVIDER;"
            "END"
        )

        # We MUST use azure cli credentials here,
        # the service principal does not have sufficient permissions to create login.
        self.execute_sql(sql, self._cli_credentials)
        self.logger.info(f"Created Login for {login_user}")

    def create_db_user(self, user_name: str, role: str = None, database: str = None):
        """
        Create db user from external provider and assign the role.
        In case of AD User/Group, the login should exist already.

        Parameters
        ----------
        user_name : str
            Name of the user to be created

        role : str
            Optional.
            Role to be assigned to the new user. If None, no role will be assigned.

        database : str = None
            Optional.
            Name of the database to create the db user
        """
        db_name = database if database is not None else self._database
        sql = (
            f"USE [{db_name}];"
            "IF NOT EXISTS"
            f"(SELECT * FROM sys.database_principals WHERE name='{user_name}') "
            "BEGIN "
            f"   CREATE USER [{user_name}] FOR LOGIN[{user_name}];"
            "END "
        )
        if role is not None:
            sql = sql + f"ALTER ROLE {role} ADD MEMBER [{user_name}];"

        self.execute_sql(sql, self._cli_credentials)
        self.logger.info(
            f"Created User for {user_name} in {db_name}," f"assigned role {role}"
        )
