import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from src.helpers.datasecurity.data_security_storage import DataSecurityStorage
from src.helpers.config import Configuration


class TestDataSecurityStorage(unittest.TestCase):
    helper: DataSecurityStorage

    def get_helper(self):
        test_dir = Path(__file__).parent
        test_config_file = f"{test_dir}/.env.test"
        config = Configuration(test_config_file)
        self.helper = DataSecurityStorage(config)
        return self.helper

    @patch("src.helpers.datasecurity.data_security_storage.GraphClient.get")
    def test_get_ad_group_id(self, mock_graph_client: MagicMock):

        # Arrange
        expected_id = "id001"
        get_mock = MagicMock()
        get_mock.json.return_value = {"value": [{"id": expected_id}]}
        mock_graph_client.return_value = get_mock

        # Act
        helper = self.get_helper()
        result = helper._get_ad_group_id("group1")

        # Assert
        assert result == expected_id

    def test_flatten_list_with_flat_list(self):
        # arrange
        flat_list = ["a", "b", "c"]
        helper = self.get_helper()
        expected_result = flat_list
        # act
        result = helper._flatten_list(flat_list)
        # assert
        self.assertEqual(expected_result, result)

    def test_flatten_list_with_nested_list(self):
        # arrange
        nested_list = ["a", "b", ["c", "d", "e"]]
        helper = self.get_helper()
        expected_result = ["a", "b", "c", "d", "e"]
        # act
        result = helper._flatten_list(nested_list)
        # assert
        self.assertEqual(expected_result, result)

    @patch(
        "src.helpers.datasecurity.data_security_storage.DataSecurityStorage"
        "._get_ad_group_id"
    )
    def test_get_security_groups_acl_succeeds_with_ids(self, mock_get_id: MagicMock):

        # Arrange
        security_groups = ["g1", "g2", "g3"]
        ids = ["id-001", "id-002", "id-003"]
        mock_get_id.side_effect = ids
        expected_acls = [
            f"group:{ids[0]}:r-x",
            f"group:{ids[1]}:r-x",
            f"group:{ids[2]}:r-x",
        ]

        # Act
        helper = self.get_helper()
        result = helper.get_security_groups_acl(security_groups)

        # Assert
        self.assertTrue(all(key in result.keys() for key in security_groups))
        self.assertTrue(all(val in result.values() for val in expected_acls))

    @patch(
        "src.helpers.datasecurity.data_security_storage.DataSecurityStorage"
        ".get_directory_client"
    )
    def test_apply_acl_to_view_recursively(self, mock_d_client: MagicMock):

        # Arrange
        mock_update = MagicMock()
        mock_update = mock_d_client.return_value.update_access_control_recursive
        mock_update.return_value = None
        path_to_view_dir = "container/version"
        view_dir = "testview"
        acl = "group:1111:r-x"

        # Act
        helper = self.get_helper()
        helper.apply_acl_to_view_recursively(
            path_to_view_dir=path_to_view_dir, view_dir=view_dir, acl=acl
        )

        # Assert
        mock_d_client.assert_called_once_with(path_to_view_dir, view_dir)
        mock_update.assert_called_once_with(acl=acl)

    @patch(
        "src.helpers.datasecurity.data_security_storage.DataSecurityStorage"
        ".get_directory_client"
    )
    def test_apply_acl_to_directory(self, mock_d_client: MagicMock):

        # Arrange
        mock_set_ac = MagicMock()
        mock_set_ac = mock_d_client.return_value.set_access_control
        mock_set_ac.return_value = None
        fs_path = "container/version"
        dir = "testview"
        acl = "group:1111:r-x"

        # Act
        helper = self.get_helper()
        helper.apply_acl_to_directory(file_system_path=fs_path, directory=dir, acl=acl)

        # Assert
        mock_d_client.assert_called_once_with(fs_path, dir)
        mock_set_ac.assert_called_once_with(acl=acl)

    @patch(
        "src.helpers.datasecurity.data_security_storage.DataSecurityStorage"
        ".apply_acl_to_view_recursively"
    )
    def test_apply_acl_to_all_views(self, mock_apply_acl: MagicMock):

        # Arrange
        assigned_security_groups = {"view1": "groupA", "view2": ["groupA", "groupB"]}
        security_group_acl = {"groupA": "group:1111:r-x", "groupB": "group:2222:r-x"}

        # Act
        helper = self.get_helper()
        helper.apply_acl_to_all_views(
            assigned_security_groups=assigned_security_groups,
            security_groups_acls=security_group_acl,
            container="container",
            path_to_views="path_to_views",
        )

        # Assert
        assert len(mock_apply_acl.mock_calls) == 3

    @patch(
        "src.helpers.datasecurity.data_security_storage.DataSecurityStorage"
        ".apply_acl_to_directory"
    )
    def test_apply_acl_to_parent_directories(self, mock_apply_acl: MagicMock):

        # Arrange
        acl1 = "group:1111:r-x"
        acl2 = "group:2222:r-x"
        security_group_acl = {"groupA": acl1, "groupB": acl2}
        comma_separated_acl_list = f"{acl1},{acl2}"
        path_to_views = "path/folder/subfolder"

        # Act
        helper = self.get_helper()
        helper.apply_acl_to_parent_directories(
            security_groups_acls=security_group_acl,
            container="container",
            path_to_views=path_to_views,
        )

        # Assert
        assert len(mock_apply_acl.mock_calls) == 3
        mock_apply_acl.assert_called_with(
            file_system_path="container",
            directory=f"/{path_to_views}",
            acl=comma_separated_acl_list,
        )

    @patch(
        "src.helpers.datasecurity.data_security_storage.DataSecurityStorage."
        "get_security_groups_acl"
    )
    @patch(
        "src.helpers.datasecurity.data_security_storage.DataSecurityStorage."
        "apply_acl_to_all_views"
    )
    @patch(
        "src.helpers.datasecurity.data_security_storage.DataSecurityStorage."
        "apply_acl_to_parent_directories"
    )
    def test_apply_acl_to_storage_for_security(
        self,
        mock_apply_acl_all_dir: MagicMock,
        mock_apply_acl_views: MagicMock,
        mock_acl: MagicMock,
    ):

        # Arrange
        assigned_security_groups = {"view1": "groupA", "view2": "groupB"}

        acl1 = "group:1111:r-x"
        acl2 = "group:2222:r-x"
        security_group_acl = {"groupA": acl1, "groupB": acl2}
        mock_acl.return_value = security_group_acl

        # Act
        helper = self.get_helper()
        helper.apply_acl_to_storage_for_security(
            container="container",
            path="v1",
            assigned_security_groups=assigned_security_groups,
        )

        # Assert
        mock_acl.assert_called_once()
        mock_apply_acl_views.assert_called_once_with(
            assigned_security_groups=assigned_security_groups,
            security_groups_acls=security_group_acl,
            container="container",
            path_to_views="v1",
        )
        mock_apply_acl_all_dir.assert_called_once_with(
            security_groups_acls=security_group_acl,
            container="container",
            path_to_views="v1",
        )

    @patch(
        "src.helpers.datasecurity.data_security_storage.DataSecurityStorage."
        "get_security_groups_acl"
    )
    @patch(
        "src.helpers.datasecurity.data_security_storage.DataSecurityStorage."
        "apply_acl_to_all_views"
    )
    @patch(
        "src.helpers.datasecurity.data_security_storage.DataSecurityStorage."
        "apply_acl_to_parent_directories"
    )
    def test_apply_acl_to_storage_for_security_column_level_security(
        self,
        mock_apply_acl_all_dir: MagicMock,
        mock_apply_acl_views: MagicMock,
        mock_acl: MagicMock,
    ):

        # Arrange
        group_a = "groupA"
        group_b = "groupB"
        column_security_groups = {
            "column1": group_a,
            "column2": group_a,
            "column3": group_b,
        }
        assigned_security_groups = {
            "view1": column_security_groups,
            "view2": group_b,
            "view3": group_b,
        }

        acl1 = "group:1111:r-x"
        acl2 = "group:2222:r-x"
        security_group_acl = {group_a: acl1, group_b: acl2}
        mock_acl.return_value = security_group_acl

        expected_security_groups = {
            "view1": [group_a, group_b],
            "view2": group_b,
            "view3": group_b,
        }

        # Act
        helper = self.get_helper()
        helper.apply_acl_to_storage_for_security(
            container="container",
            path="v1",
            assigned_security_groups=assigned_security_groups,
        )

        # Assert
        mock_acl.assert_called_once()
        mock_apply_acl_views.assert_called_once_with(
            assigned_security_groups=expected_security_groups,
            security_groups_acls=security_group_acl,
            container="container",
            path_to_views="v1",
        )
        mock_apply_acl_all_dir.assert_called_once_with(
            security_groups_acls=security_group_acl,
            container="container",
            path_to_views="v1",
        )


if __name__ == "__main__":
    unittest.main()
