"""
Purview Data Source helper module
"""
import logging
from typing import Any

from ..config import Configuration
from .clients import ClientHelper
from .scans import ScanHelper


class DataSourceHelper:
    """
    Data Source helper functions
    """

    def __init__(self, configuration: Configuration):
        self._configuration = configuration
        self.logger = logging.getLogger(__name__)
        purviewhelper = ClientHelper(account_name=configuration.purview_account_name)
        self._scanning_client = purviewhelper.get_scanning_client()

    def register_synapse_data_source(
        self,
        data_source_name: str,
        collection_name: str,
        workspace_name: str,
        location: str,
        subscription_id: str,
        resource_group_name: str,
    ) -> Any:
        """
        Registers a Data Source in Purview
        """
        # https://docs.microsoft.com/en-us/rest/api/purview/scanningdataplane/data-sources/create-or-update?tabs=HTTP#examples
        resource_id = (
            f"/subscriptions/{subscription_id}/"
            f"resourceGroups/{resource_group_name}/providers/"
            f"Microsoft.Synapse/workspaces/{workspace_name}"
        )
        data_source_def = {
            "kind": "AzureSynapseWorkspace",
            "name": "synapse-devjdffordata",
            "properties": {
                "subscriptionId": subscription_id,
                "dedicatedSqlEndpoint": f"{workspace_name}.sql.azuresynapse.net",
                "serverlessSqlEndpoint": f"{workspace_name}"
                + "-ondemand.sql.azuresynapse.net",
                "resourceGroup": resource_group_name,
                "location": location,
                "resourceName": workspace_name,
                "resourceId": resource_id,
                "collection": {
                    "type": "CollectionReference",
                    "referenceName": collection_name,
                },
                "dataUseGovernance": "Disabled",
            },
        }

        try:
            response = self._scanning_client.data_sources.create_or_update(
                data_source_name=data_source_name, body=data_source_def
            )
            return response
        except Exception as ex:
            self.logger.error(ex)

    def get_data_source(
        self,
        data_source_name: str,
    ):
        """
        Executes the get_data_source command option
        """
        try:
            response = self._scanning_client.data_sources.get(
                data_source_name=data_source_name
            )
            return response
        except Exception as ex:
            self.logger.error(ex)
            return None

    def delete_data_source(
        self,
        data_source_name: str,
    ):
        """
        Executes the delete_data_source command option
        """
        try:
            stop_scans_result = self.stop_all_scans(data_source_name=data_source_name)
            if stop_scans_result:
                response = self._scanning_client.data_sources.delete(
                    data_source_name=data_source_name
                )
                return response
            else:
                self.logger.warning(
                    f"Could not delete data source {data_source_name} because scans"
                    "are still running"
                )
                return None
        except Exception as ex:
            self.logger.error(ex)

    def stop_all_scans(self, data_source_name: str) -> bool:
        """
        Stops all scans in data source
        """
        try:
            scan_helper = ScanHelper(self._configuration)
            scans = scan_helper.get_scan_definitions(data_source_name=data_source_name)
            if scans:
                for scan in scans:
                    scan_name = scan["name"]
                    history = scan_helper.get_scan_history(
                        data_source_name=data_source_name, scan_name=scan_name
                    )
                    if history:
                        for run in history:
                            run_id = run["id"]
                            if not scan_helper.check_scan_run_is_complete(
                                run_id=run_id,
                                data_source_name=data_source_name,
                                scan_name=scan["name"],
                            ):
                                scan_helper.cancel_scan(
                                    data_source_name=data_source_name,
                                    scan_name=scan_name,
                                    run_id=run_id,
                                )
            return True

        except Exception as ex:
            self.logger.error(ex)
            return False

    def get_data_sources(self):
        """
        Get all data sources
        """
        try:
            response = self._scanning_client.data_sources.list_all()
            return response
        except Exception as ex:
            self.logger.error(ex)
