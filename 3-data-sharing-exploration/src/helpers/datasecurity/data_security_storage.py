import logging
from typing import Dict, List

from azure.core.exceptions import ResourceNotFoundError
from azure.identity import DefaultAzureCredential
from azure.storage.filedatalake import DataLakeServiceClient
from msgraph.core import GraphClient

from ..config import Configuration
from ..storage import StorageHelper
from .data_security_common import DataSecurityCommon


class DataSecurityStorage:
    """Contains methods for managing data security in storage"""

    _datalake_service_client: DataLakeServiceClient

    def __init__(self, configuration: Configuration):
        self.logger = logging.getLogger(__name__)
        self._configuration = configuration
        self._credentials = DefaultAzureCredential()
        self._datalake_service_client = DataLakeServiceClient(
            account_url=(
                f"https://{configuration.storage_account_name}.dfs.core.windows.net"
            ),
            credential=self._credentials,
        )
        self._storage_helper = StorageHelper(configuration.storage_account_name)
        self._security_common = DataSecurityCommon(configuration)
        self.logger.info("DataSecurityStorage initialized")

    def _get_ad_group_id(self, group_name):
        """
        Get the AD Group ID based on its name
        """
        app_client = GraphClient(
            credential=self._credentials,
            scopes=["https://graph.microsoft.com/.default"],
        )
        endpoint = "/groups"
        request_url = f"{endpoint}?$filter=displayName eq '{group_name}'"
        groups_response = app_client.get(request_url)
        groups = groups_response.json()
        if len(groups.get("value", {})) > 0:
            return groups["value"][0]["id"]
        else:
            return None

    def _flatten_list(self, list_to_flatten: List):
        """
        Flatten a list composed of strings and sublists
        """
        result = []
        for item in list_to_flatten:
            if isinstance(item, list):
                result.extend(self._flatten_list(item))
            else:
                result.append(item)
        return result

    def get_security_groups_acl(self, security_groups: List) -> Dict[str, str]:
        """
        Creates mapping of security group names and ACL statements, based on object ids.
        """
        security_groups_acl = {}
        # if the list contains lists, then we flatten it
        security_group_flatten_list = self._flatten_list(security_groups)
        unique_group_names = set(val for val in security_group_flatten_list)

        for group_name in unique_group_names:
            object_id = self._get_ad_group_id(group_name)
            if object_id is not None:
                acl = f"group:{object_id}:r-x"
                security_groups_acl[group_name] = acl
            else:
                self.logger.warning(
                    f"AD Group {group_name} not found - using static env variable"
                )
                # temp solution: get AD Groups object ids from env file
                match group_name:
                    case "Security_Group_A":
                        env_group_id = self._configuration.security_group_a_oid
                    case "Security_Group_B":
                        env_group_id = self._configuration.security_group_b_oid
                    case "Security_Group_C":
                        env_group_id = self._configuration.security_group_c_oid
                acl = f"group:{env_group_id}:r-x"
                security_groups_acl[group_name] = acl

        return security_groups_acl

    def get_directory_client(self, file_system_path: str, directory_name: str):
        """
        Returns ADLS directory client.
        """
        file_system_client = self._datalake_service_client.get_file_system_client(
            file_system=f"{file_system_path}"
        )
        return file_system_client.get_directory_client(directory_name)

    def apply_acl_to_view_recursively(
        self, path_to_view_dir: str, view_dir: str, acl: str
    ):
        """
        Apply ACL to a view directory (and subdirectories/files) in ADLS2
        """

        self.logger.info(f"Applying permissions to the view {view_dir}")

        try:
            directory_client = self.get_directory_client(
                f"{path_to_view_dir}", view_dir
            )
            directory_client.update_access_control_recursive(acl=acl)

            self.logger.info(
                f"Successfully applied ACL: [{acl}] to the view {view_dir}"
            )
        except ResourceNotFoundError as e:
            self.logger.warning(f"Resource not found. Skipping. {e.reason}")
        except Exception as e:
            self.logger.error(f"Error applying permissions to the view {view_dir}: {e}")

    def apply_acl_to_directory(self, file_system_path: str, directory: str, acl: str):
        """
        Apply ACL to a directory in ADLS2
        """

        self.logger.info(f"Applying permissions to the directory {directory}")

        try:
            directory_client = self.get_directory_client(file_system_path, directory)
            directory_client.set_access_control(acl=acl)

            self.logger.info(
                f"Successfully applied acl: [{acl}] to the directory {directory}"
            )
        except ResourceNotFoundError as e:
            self.logger.warning(f"The resource not found. Skipping. {e.reason}")
        except Exception as e:
            self.logger.error(
                f"Error applying permissions to the directory {directory}: {e}"
            )

    def apply_acl_to_all_views(
        self,
        assigned_security_groups: dict,
        security_groups_acls: dict,
        container: str,
        path_to_views: str,
    ):
        """
        Apply ACL to all views based on the assigned security group(s)
        """
        # get the schema form env variable just to compose the folder
        schema = self._configuration.schema_name

        for view in assigned_security_groups.keys():
            group = assigned_security_groups.get(view)
            # if the value is a string, then we apply ACL to a single group
            if isinstance(group, str):
                self.apply_acl_to_view_recursively(
                    path_to_view_dir=f"{container}/{path_to_views}",
                    view_dir=f"{schema}_{view}",
                    acl=security_groups_acls.get(group),
                )
                self.logger.info(f"Assigned ACL: {group} has access to {view}")
                print(f"Assigned ACL: {group} has access to {view}")
            # if the value is a list, then we apply ACL to all groups.
            else:
                for item in group:
                    self.apply_acl_to_view_recursively(
                        path_to_view_dir=f"{container}/{path_to_views}",
                        view_dir=f"{schema}_{view}",
                        acl=security_groups_acls.get(item),
                    )
                    self.logger.info(f"Assigned ACL: {item} has access to {view}")
                    print(f"Assigned ACL: {item} has access to {view}")

    def apply_acl_to_parent_directories(
        self,
        container: str,
        path_to_views: str,
        security_groups_acls: dict,
    ):
        """
        Apply ACL to all parent directories
        """

        # get security groups ACLs as single string.
        # This is required to use the 'set' method to apply ACL to directories
        comma_separated_acl_list = ",".join(security_groups_acls.values())

        directories = path_to_views.split("/")
        path = "/"
        for item in directories:
            directory = f"{path}{item}"
            self.apply_acl_to_directory(
                file_system_path=container,
                directory=directory,
                acl=comma_separated_acl_list,
            )
            self.logger.info(f"Assigned ACL to folder: {directory}")
            print(f"Assigned ACL to folder: {directory}")
            path = path + f"{item}/"

    def apply_acl_to_storage_for_security(
        self, container: str, path: str, assigned_security_groups: dict
    ) -> dict():
        """
        Based on the Security Groups gathered from Purview,
        apply ACL to all View folders/subfolders/files and parent folders

        Parameters
        --------
        container: str
            The container where to apply ACL

        path: str
            The folder structure within the container

        assigned_security_groups: dict(str: str | dict)
            The dictionary of security information to be used to apply ACL.
            key: view name
            value:  security group in case of table level security
                    dict(column_name: security group) in case of column level security

        Returns
        --------
        dict(str: str)
        The dictionary with unique security groups and corresponding ACLs applied.
        """

        # Remove column names and duplicate security groups applied to different columns
        # in the same view, unnecessary information to apply ACL
        for item in assigned_security_groups:
            if isinstance(assigned_security_groups.get(item), dict):
                unique_security_groups_in_view = list(
                    dict.fromkeys(assigned_security_groups.get(item).values())
                )
                assigned_security_groups[item] = unique_security_groups_in_view
        self.logger.info(
            "Removed unnecessary column information. Assigned security groups: "
            f"{assigned_security_groups}"
        )

        # get ACL for the assigned groups
        security_groups_acls = self.get_security_groups_acl(
            security_groups=assigned_security_groups.values()
        )

        # apply ACL to all Views in the metadata file
        self.apply_acl_to_all_views(
            assigned_security_groups=assigned_security_groups,
            security_groups_acls=security_groups_acls,
            container=container,
            path_to_views=path,
        )
        self.logger.info(f"ACL applied to all Views in {container}/{path}/")

        # apply ACL to all parent directories
        self.apply_acl_to_parent_directories(
            security_groups_acls=security_groups_acls,
            container=container,
            path_to_views=path,
        )
        self.logger.info(f"ACL applied to parent directories: {path}")

        return security_groups_acls
