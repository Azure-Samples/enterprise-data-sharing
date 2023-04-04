"""
Purview SDK helper functions
"""

import logging
import uuid
from typing import Any, List

from azure.core.exceptions import HttpResponseError
from azure.purview.scanning import PurviewScanningClient

from ..config import Configuration
from .clients import ClientHelper


class ScanHelper:
    """
    Purview SDK helper functions for scanning
    """

    _scanning_client: PurviewScanningClient

    def __init__(self, configuration: Configuration):
        self._configuration = configuration
        self.logger = logging.getLogger(__name__)
        purviewhelper = ClientHelper(account_name=configuration.purview_account_name)
        self._scanning_client = purviewhelper.get_scanning_client()

    def create_synapse_scan_definition(
        self,
        data_source_name: str,
        scan_name: str,
        collection_name: str,
        db_names: List[str],
    ):
        """
        Creates a scan definition with Purview for Synapse
        """
        try:

            scan_definition: Any = {
                "kind": "AzureSynapseWorkspaceMsi",
                "properties": {
                    "resourceTypes": {
                        "AzureSynapseServerlessSql": {
                            "resourceNameFilter": {"resources": db_names},
                            "scanRulesetName": "AzureSynapseSQL",
                            "scanRulesetType": "System",
                        }
                    },
                    "collection": {
                        "referenceName": collection_name,
                        "type": "CollectionReference",
                    },
                },
            }

            response = self._scanning_client.scans.create_or_update(
                data_source_name=data_source_name,
                scan_name=scan_name,
                body=scan_definition,
            )
            return response

        except (ValueError, HttpResponseError) as ex:
            self.logger.error(ex)

    def get_scan_definitions(self, data_source_name: str):
        """
        Get all scan definitions
        """
        self.logger.info(f"get_scan_definitions for '{data_source_name}'")
        try:
            response = self._scanning_client.scans.list_by_data_source(
                data_source_name=data_source_name
            )
            return response

        except (ValueError, HttpResponseError) as ex:
            self.logger.error(ex)

    def trigger_scan(self, data_source_name: str, scan_name: str):
        """
        Triggers a scan
        """
        try:
            run_id = uuid.uuid4()
            response = self._scanning_client.scan_result.run_scan(
                data_source_name=data_source_name,
                scan_name=scan_name,
                run_id=str(run_id),
            )
            return response

        except (ValueError, HttpResponseError) as ex:
            self.logger.error(ex)

    def get_scan_history(self, data_source_name: str, scan_name: str):
        """
        Get the history of scan definition
        """
        try:
            response = self._scanning_client.scan_result.list_scan_history(
                data_source_name=data_source_name, scan_name=scan_name
            )
            return response

        except (ValueError, HttpResponseError) as ex:
            self.logger.error(ex)

    def _scan_result_is_complete(self, scan_result: Any) -> bool:
        status = scan_result["status"]
        return status == "Succeeded" or status == "Failed" or status == "Canceled"

    def check_scan_run_is_complete(
        self, run_id: str, data_source_name: str, scan_name: str
    ) -> bool:
        """
        Checks if a scan is complete.
        """
        try:
            response = self._scanning_client.scan_result.list_scan_history(
                data_source_name=data_source_name, scan_name=scan_name
            )

            scan_results = [
                scan_result
                for scan_result in response
                if scan_result["id"] == run_id or scan_result["parentId"] == run_id
            ]

            if len(scan_results) == 0:
                # we return True because there's nothing to wait for
                self.logger.warning(f"Could not find scan {run_id} in history")
                return True

            for scan_result in scan_results:
                if not self._scan_result_is_complete(scan_result):
                    self.logger.info(f"Scan {scan_result['id']} is not complete")
                    return False

            return True

        except (ValueError, HttpResponseError) as ex:
            # we return True because there's nothing to wait for
            self.logger.error(ex)
            return True

    def cancel_scan(self, data_source_name: str, scan_name: str, run_id: str):
        """
        Cancel a scan run
        """
        try:
            response = self._scanning_client.scan_result.cancel_scan(
                data_source_name=data_source_name, scan_name=scan_name, run_id=run_id
            )
            return response

        except (ValueError, HttpResponseError) as ex:
            self.logger.error(ex)
