import unittest
from pathlib import Path
from unittest.mock import MagicMock, call, patch

from src.helpers.config import Configuration
from src.helpers.sql import SqlHelper


class TestSqlHelper(unittest.TestCase):
    helper: SqlHelper

    def get_helper(self, use_cli_cred: bool = False):
        test_dir = Path(__file__).parent
        test_config_file = f"{test_dir}/.env.test"
        config = Configuration(test_config_file)
        self.helper = SqlHelper(config, use_cli_cred)
        return self.helper

    def get_test_metadata_as_json(self):
        test_dir = Path(__file__).parent
        test_metadata_file = f"{test_dir}/data/test_metadata.json"
        with open(test_metadata_file) as f:
            content = f.read()
        return content

    @patch("src.helpers.sql.SqlHelper.get_connection_cursor")
    def test_execute_sql_result(
        self,
        mock_get_cursor: MagicMock,
    ):
        # arrange
        expected_res = ["result1", "result2"]
        cursor_mock = MagicMock()
        cursor_mock.execute.return_value = MagicMock()
        cursor_mock.fetchone.side_effect = [expected_res[0], expected_res[1], None]
        mock_get_cursor.return_value = cursor_mock

        # act
        sql_helper = self.get_helper()
        result = sql_helper.execute_sql_result("sql statement")

        # assert
        assert len(cursor_mock.fetchone.mock_calls) == 3
        assert len(result) == 2
        self.assertEqual(expected_res, result)

    @patch("src.helpers.sql.SqlHelper.execute_sql")
    def test_create_external_data_source(
        self,
        mock_exec_sql: MagicMock,
    ):
        # arrange
        version = "version1"
        container = "testcontainer"

        # act
        sql_helper = self.get_helper()
        schema = sql_helper._configuration.schema_name
        expected_result = f"{version}_{schema}"

        result = sql_helper.create_external_data_source(
            path=version, container_name=container, schema=schema
        )

        # assert
        mock_exec_sql.assert_called_once()
        self.assertEqual(expected_result, result)

    @patch("src.helpers.sql.SqlHelper.execute_sql")
    def test_create_or_update_view(self, mock_execute_sql: MagicMock):
        # arrange
        sql_helper = self.get_helper()
        external_ds = "external_ds"
        schema = sql_helper._configuration.schema_name
        table = "table1"
        full_table_name = f"{schema}_{table}"
        version = "v1"
        calls = [
            call(
                f"CREATE OR ALTER VIEW {version}_{schema}.{table}"
                f" AS SELECT * FROM     OPENROWSET(        BULK '{full_table_name}',"
                f"        DATA_SOURCE = '{external_ds}',        FORMAT = 'DELTA'    )"
                f" {table}"
            ),
        ]

        # act
        sql_helper.create_or_update_view(external_ds, version, full_table_name, schema)

        # assert
        mock_execute_sql.assert_has_calls(calls)

    @patch("src.helpers.sql.SqlHelper.create_external_data_source")
    @patch("src.helpers.sql.SqlHelper.create_schema")
    @patch("src.helpers.sql.SqlHelper.create_or_update_view")
    def test_create_views_from_metadata(
        self,
        mock_create_or_update_view: MagicMock,
        mock_create_schema: MagicMock,
        mock_create_external_data_source: MagicMock,
    ):
        # arrange
        sql_helper = self.get_helper()
        metadata_json = self.get_test_metadata_as_json()
        container_name = sql_helper._configuration.container_name
        version = "v1"
        schema_name = sql_helper._configuration.schema_name

        external_data_source = "external_ds"
        mock_create_external_data_source.return_value = external_data_source

        # act
        sql_helper.create_views_from_metadata(metadata_json, schema_name)
        mock_create_external_data_source.assert_called_once_with(
            container_name=container_name, path=version, schema=schema_name
        )

        # assert
        calls = [
            call(
                external_data_source=external_data_source,
                version=version,
                folder_name=f"{schema_name}_Customer",
                schema=schema_name,
            ),
            call(
                external_data_source=external_data_source,
                version=version,
                folder_name=f"{schema_name}_ProductModel",
                schema=schema_name,
            ),
        ]
        mock_create_or_update_view.assert_has_calls(calls)

    @patch("src.helpers.sql.SqlHelper.execute_sql")
    def test_create_schema(self, mock_execute_sql: MagicMock):
        # arrange
        sql_helper = self.get_helper()
        schema = sql_helper._configuration.schema_name

        calls = [
            call(
                f"IF NOT EXISTS(SELECT * FROM sys.schemas WHERE name='{schema}') "
                f"EXEC('CREATE SCHEMA {schema}');"
            ),
        ]

        # act
        sql_helper.create_schema(schema)

        # assert
        mock_execute_sql.assert_has_calls(calls)

    @patch("src.helpers.sql.SqlHelper.execute_sql_result")
    def test_list_views(self, mock_execute_sql: MagicMock):
        # arrange
        sql_helper = self.get_helper()
        schema1 = "v1_schema"
        schema2 = "v2_schema"
        view1 = ("view1",)
        view2 = "view2"
        sql_res = [[schema1, view1], [schema1, view2], [schema2, view2]]
        mock_execute_sql.return_value = sql_res
        expected_res = [
            f"{schema1}.{view1}",
            f"{schema1}.{view2}",
            f"{schema2}.{view2}",
        ]

        # act
        result = sql_helper.list_views()

        # assert
        self.assertEqual(expected_res, result)

    @patch("src.helpers.sql.SqlHelper.execute_sql")
    @patch("src.helpers.sql.SqlHelper.list_views")
    def test_drop_all_views(self, mock_views: MagicMock, mock_execute_sql: MagicMock):
        # arrange
        sql_helper = self.get_helper()
        schema1 = "v1_schema"
        schema2 = "v2_schema"
        view1 = ("view1",)
        view2 = "view2"
        views = [f"{schema1}.{view1}", f"{schema1}.{view2}", f"{schema2}.{view2}"]
        mock_views.return_value = views

        # act
        sql_helper.drop_all_views()

        # assert
        assert len(mock_execute_sql.mock_calls) == 3
        mock_execute_sql.assert_called_with(f"DROP VIEW {schema2}.{view2}")

    @patch("src.helpers.sql.SqlHelper.get_connection_cursor_az_cli_token")
    @patch("src.helpers.sql.SqlHelper.get_connection_cursor")
    def test_execute_sql_using_sp_credentials(
        self, mock_cursor: MagicMock, mock_cursor_cli: MagicMock
    ):
        # arrange
        sql_helper = self.get_helper()
        sql = "any sql statement"
        # act
        sql_helper.execute_sql(sql, use_cli_cred=False)
        # assert
        mock_cursor_cli.assert_not_called()
        mock_cursor.assert_called_once()

    @patch("src.helpers.sql.SqlHelper.get_connection_cursor_az_cli_token")
    @patch("src.helpers.sql.SqlHelper.get_connection_cursor")
    def test_execute_sql_using_azcli_credentials(
        self, mock_cursor: MagicMock, mock_cursor_cli: MagicMock
    ):
        # arrange
        sql_helper = self.get_helper()
        sql = "any sql statement"
        # act
        sql_helper.execute_sql(sql, use_cli_cred=True)
        # assert
        mock_cursor.assert_not_called()
        mock_cursor_cli.assert_called_once()

    @patch("src.helpers.sql.SqlHelper.execute_sql")
    def test_create_database_azcli_cred(self, mock_execute_sql: MagicMock):
        # arrange
        sql_helper = self.get_helper(use_cli_cred=True)
        db_name = sql_helper._configuration.synapse_database

        calls = [
            call(
                f"IF NOT EXISTS(SELECT * FROM sys.databases WHERE name='{db_name}') "
                "BEGIN "
                f"   CREATE DATABASE [{db_name}] "
                "END",
                True
            ),
        ]

        # act
        sql_helper.create_database(db_name)

        # assert
        mock_execute_sql.assert_has_calls(calls)
        self.assertEqual(sql_helper._database, db_name)

    @patch("src.helpers.sql.SqlHelper.execute_sql")
    def test_drop_database(self, mock_execute_sql: MagicMock):
        # arrange
        sql_helper = self.get_helper()
        db_name = sql_helper._configuration.synapse_database

        calls = [
            call(
                f"IF EXISTS(SELECT * FROM sys.databases WHERE name='{db_name}') "
                "BEGIN "
                f"   DROP DATABASE {db_name} "
                "END"
            ),
        ]

        # act
        sql_helper.drop_database(db_name)

        # assert
        mock_execute_sql.assert_has_calls(calls)
        self.assertNotEqual(sql_helper._database, db_name)

    @patch("src.helpers.sql.SqlHelper.execute_sql")
    def test_create_login(self, mock_execute_sql: MagicMock):
        # arrange
        sql_helper = self.get_helper(use_cli_cred=True)
        login_user = "login123"

        sql = (
            "IF NOT EXISTS"
            f"(SELECT * FROM sys.server_principals WHERE name='{login_user}') "
            "BEGIN "
            f"   CREATE LOGIN [{login_user}] FROM EXTERNAL PROVIDER;"
            "END"
        )

        # act
        sql_helper.create_login(login_user)

        # assert
        mock_execute_sql.assert_called_once_with(sql, True)

    @patch("src.helpers.sql.SqlHelper.execute_sql")
    def test_create_db_user_no_role_no_db(self, mock_execute_sql: MagicMock):
        # arrange
        sql_helper = self.get_helper()
        db_user = "user123"
        db_name = sql_helper._configuration.synapse_database

        sql = (
            f"USE [{db_name}];"
            "IF NOT EXISTS"
            f"(SELECT * FROM sys.database_principals WHERE name='{db_user}') "
            "BEGIN "
            f"   CREATE USER [{db_user}] FOR LOGIN[{db_user}];"
            "END "
        )

        # act
        sql_helper.create_db_user(db_user)

        # assert
        mock_execute_sql.assert_called_once_with(sql, False)

    @patch("src.helpers.sql.SqlHelper.execute_sql")
    def test_create_db_user_with_role_no_db(self, mock_execute_sql: MagicMock):
        # arrange
        sql_helper = self.get_helper()
        db_user = "user123"
        db_name = sql_helper._configuration.synapse_database
        role = "any_role"

        sql = (
            f"USE [{db_name}];"
            "IF NOT EXISTS"
            f"(SELECT * FROM sys.database_principals WHERE name='{db_user}') "
            "BEGIN "
            f"   CREATE USER [{db_user}] FOR LOGIN[{db_user}];"
            "END "
            f"ALTER ROLE {role} ADD MEMBER [{db_user}];"
        )

        # act
        sql_helper.create_db_user(db_user, role)

        # assert
        mock_execute_sql.assert_called_once_with(sql, False)

    @patch("src.helpers.sql.SqlHelper.execute_sql")
    def test_create_db_user_with_role_and_db(self, mock_execute_sql: MagicMock):
        # arrange
        sql_helper = self.get_helper()
        db_user = "user123"
        db_name = "database1"
        role = "any_role"

        sql = (
            f"USE [{db_name}];"
            "IF NOT EXISTS"
            f"(SELECT * FROM sys.database_principals WHERE name='{db_user}') "
            "BEGIN "
            f"   CREATE USER [{db_user}] FOR LOGIN[{db_user}];"
            "END "
            f"ALTER ROLE {role} ADD MEMBER [{db_user}];"
        )

        # act
        sql_helper.create_db_user(db_user, role, db_name)

        # assert
        mock_execute_sql.assert_called_once_with(sql, False)


if __name__ == "__main__":
    unittest.main()
