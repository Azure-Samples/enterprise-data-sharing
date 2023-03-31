import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from src.helpers.datasecurity.data_security_common import DataSecurityCommon
from src.helpers.config import Configuration
from src.helpers.metadata import Table, Column


class TestDataSecurityCommon(unittest.TestCase):
    helper: DataSecurityCommon

    def get_helper(self):
        test_dir = Path(__file__).parent
        test_config_file = f"{test_dir}/.env.test"
        config = Configuration(test_config_file)
        self.helper = DataSecurityCommon(config)
        return self.helper

    @patch(
        "src.helpers.datasecurity.data_security_common.CatalogHelper."
        "get_synapse_table_fully_qualified_name"
    )
    @patch(
        "src.helpers.datasecurity.data_security_common.CatalogHelper."
        "get_entity_id_by_fully_qualified_name"
    )
    @patch(
        "src.helpers.datasecurity.data_security_common.ManagedAttributesHelper."
        "get_m_attribute_value"
    )
    @patch(
        "src.helpers.datasecurity.data_security_common.DataSecurityCommon."
        "get_security_for_view_columns"
    )
    def test_get_security_for_views(
        self,
        mock_security_columns: MagicMock,
        mock_attribute: MagicMock,
        mock_entity_id: MagicMock,
        mock_table_name: MagicMock,
    ):

        # Arrange
        groupA = "security_group_A"
        groupB = "security_group_B"
        expected_result = {"Table1": groupA, "Table2": groupB}

        metadata_json = (
            '{"version": "1", "path": "v1", "tables": '
            '[{"name": "Table1", "columns": []}, {"name": "Table2", "columns": []}]}'
        )
        mock_attribute.side_effect = [groupA, groupB]

        # Act
        helper = self.get_helper()
        result = helper.get_security_for_views(
            metadata_json, "anyattribute", "anygroup"
        )

        # Assert
        self.assertEqual(expected_result, result)
        mock_security_columns.assert_not_called()

    @patch(
        "src.helpers.datasecurity.data_security_common.CatalogHelper."
        "get_synapse_table_fully_qualified_name"
    )
    @patch(
        "src.helpers.datasecurity.data_security_common.CatalogHelper."
        "get_entity_id_by_fully_qualified_name"
    )
    @patch(
        "src.helpers.datasecurity.data_security_common.ManagedAttributesHelper."
        "get_m_attribute_value"
    )
    @patch(
        "src.helpers.datasecurity.data_security_common.DataSecurityCommon."
        "get_security_for_view_columns"
    )
    def test_get_security_for_views_with_column_level_security(
        self,
        mock_security_columns: MagicMock,
        mock_attribute: MagicMock,
        mock_entity_id: MagicMock,
        mock_table_name: MagicMock,
    ):

        # Arrange
        groupA = "security_group_A"
        groupB = "security_group_B"
        columns_security = {"column1": groupA, "column2": groupB, "column3": groupB}
        expected_result = {
            "Table1": columns_security,
            "Table2": groupB,
        }

        metadata_json = (
            '{"version": "1", "path": "v1", "tables": '
            '[{"name": "Table1", "columns": []}, {"name": "Table2", "columns": []}]}'
        )
        mock_attribute.side_effect = ["Not Assigned", groupB]
        mock_security_columns.return_value = columns_security

        # Act
        helper = self.get_helper()
        result = helper.get_security_for_views(
            metadata_json, "anyattribute", "anygroup"
        )

        # Assert
        self.assertEqual(expected_result, result)
        mock_security_columns.assert_called_once()

    @patch(
        "src.helpers.datasecurity.data_security_common.CatalogHelper."
        "get_entity_id_by_fully_qualified_name"
    )
    @patch(
        "src.helpers.datasecurity.data_security_common.ManagedAttributesHelper."
        "get_m_attribute_value"
    )
    def test_get_security_for_view_columns(
        self,
        mock_attribute: MagicMock,
        mock_entity_id: MagicMock,
    ):

        # Arrange
        groupA = "security_group_A"
        groupB = "security_group_B"
        expected_result = {"column1": groupA, "column2": groupB, "column3": groupB}
        table = Table(
            name="Table1",
            columns=[
                Column(name="column1"),
                Column(name="column2"),
                Column(name="column3"),
            ],
        )
        mock_attribute.side_effect = [groupA, groupB, groupB]

        # Act
        helper = self.get_helper()
        result = helper.get_security_for_view_columns(
            m_attribute_name="anyattribute",
            m_attribute_group="anygroup",
            table=table,
            table_qualified_name="anyname",
        )

        # Assert
        self.assertEqual(expected_result, result)
        assert len(mock_attribute.mock_calls) == 3


if __name__ == "__main__":
    unittest.main()
