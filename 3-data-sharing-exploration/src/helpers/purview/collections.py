"""
Purview Collection helper module
"""

import logging
import time
from typing import Dict, List

from ..const import CONST
from ..config import Configuration
from .assets import AssetHelper
from .clients import ClientHelper
from .datasources import DataSourceHelper


class CollectionHelper:
    """
    Collection helper functions
    """

    def __init__(self, configuration: Configuration):
        self._configuration = configuration
        self.logger = logging.getLogger(__name__)

        client_helper = ClientHelper(account_name=configuration.purview_account_name)
        self._account_client = client_helper.get_account_client()
        self._catalog_client = client_helper.get_catalog_client()

    def get_collection(self, collection_name: str):
        """
        Gets a collection in Purview by its name
        """
        try:
            response = self._account_client.collections.get_collection(
                collection_name=collection_name
            )
            return response
        except Exception as ex:
            self.logger.error(ex)
            return None

    def create_collection(self, collection_name: str, parent_collection_name: str = ""):
        """
        Creates a collection in Purview.
        """
        try:
            # unique name includes the parent collection to avoid collisions
            if parent_collection_name and parent_collection_name != "":
                collection_unique_name = parent_collection_name + "-" + collection_name
                collection_def = {
                    "friendlyName": collection_name,
                    "parentCollection": {"referenceName": parent_collection_name},
                }
            else:
                collection_unique_name = collection_name
                collection_def = {
                    "friendlyName": collection_name,
                }

            # prevent underscores on collection names
            collection_unique_name = collection_unique_name.replace("_", "-")

            response = self._account_client.collections.create_or_update_collection(
                collection_name=collection_unique_name, collection=collection_def
            )
            return response
        except Exception as ex:
            self.logger.error(ex)

    def delete_collection(self, collection_name: str):
        """
        Deletes a collection in Purview
        """
        try:
            self._account_client.collections.delete_collection(
                collection_name=collection_name
            )
        except Exception as ex:
            self.logger.error(ex)

    def organize_collection(self, collection_name: str):
        """
        Organizes catalog items from a given collection
        """
        if not self.get_collection(collection_name):
            self.logger.error(f"Collection {collection_name} not found")
            return

        # specify data types we want to move
        data_types = [
            CONST.PURVIEW_SYNAPSE_SQL_VIEW_DATA_TYPE,
            CONST.PURVIEW_SYNAPSE_SQL_TABLE_DATA_TYPE,
            CONST.PURVIEW_SYNAPSE_SQL_SCHEMA_DATA_TYPE,
        ]

        # get all assets
        asset_list = list()
        for data_type in data_types:
            entities = self._get_assets(collection_name, asset_type=data_type)
            asset_list.extend(entities)

        # get desired collection hierarchy from entity list
        collection_hierarchy = self._get_collection_hierarchy(asset_list)

        # create collection hierarchy and move items
        self._organize_items_in_collection_hierarchy(
            collection_hierarchy, collection_name
        )

    def get_children(self, collection_name: str) -> List[str]:
        result = []
        children = self._account_client.collections.list_child_collection_names(
            collection_name=collection_name
        )
        for child in children:
            result.append(child.get("name"))
        return result

    def cleanup_collection(self, collection_name: str):
        """
        Deletes catalog items from a given collection
        """
        datasource_helper = DataSourceHelper(configuration=self._configuration)
        if not self.get_collection(collection_name):
            self.logger.error(f"Collection {collection_name} not found")
            return
        self._delete_collection_recursively(collection_name, datasource_helper)

    def _delete_collection_recursively(
        self,
        collection_name: str,
        datasource_helper: DataSourceHelper,
    ):
        """
        Delete collection and all assets recursively
        """
        children = self.get_children(collection_name)
        for child in children:
            self._delete_collection_recursively(child, datasource_helper)
        try:
            self._delete_assets_from_collection(collection_name)
            self._delete_sources_from_collection(collection_name, datasource_helper)
        except Exception as ex:
            self.logger.error(ex)
        self.delete_collection(collection_name=collection_name)

    def _get_assets(
        self, collection_name: str, asset_type: str = "", request_limit: int = 1000
    ):
        """
        Gets all assets in collection with an optional type filter
        and a request_limit (defaults to 1000)
        """

        if asset_type != "":
            filter = {
                "and": [
                    {"collectionId": collection_name},
                    {"entityType": asset_type},
                ]
            }
        else:
            filter = {"collectionId": collection_name}

        query = {
            "filter": filter,
            "limit": request_limit,
            "offset": 0,
        }

        # perform paged query
        result_list = list()
        query_complete = False

        while not query_complete:
            results = self._catalog_client.discovery.query(query)["value"]
            if results:
                # store page results in result_list
                for result in results:
                    result_list.append(result)

                # check if we're done
                if len(results) < request_limit:
                    query_complete = True
                else:
                    # update the query with offset so we ask for next page
                    query = {
                        "filter": filter,
                        "limit": request_limit,
                        "offset": query["offset"] + request_limit,
                    }
            else:
                query_complete = True

        return result_list

    def _delete_assets_from_collection(self, collection_name: str):
        """
        Deletes all entities from a collection
        """
        self.logger.warning(f"Deleting assets for {collection_name}")
        whole_asset_list = self._get_assets(collection_name)
        # we can't delete the whole assets in one go.
        # A possible problem is 'URI Too Long' due to the number of guids
        # being supplied to the bulk operation
        id_amount = 100
        iterations = (len(whole_asset_list) // id_amount) + 1
        for x in range(iterations):
            # find slice of asset_list
            start = x * id_amount
            end = start + id_amount
            if end > len(whole_asset_list):
                end = len(whole_asset_list)

            asset_list = whole_asset_list[start:end]

            if asset_list and len(asset_list) > 0:
                delete_in_progress = True
                while delete_in_progress:
                    # Delete by guids works asynchronously and returns a status
                    # for each guid currently being deleted
                    # We'll repeat the request until we get no ACTIVE status on an asset
                    response = self._catalog_client.entity.delete_by_guids(
                        guids=[x["id"] for x in asset_list]
                    )
                    # try to identity at least one asset
                    # with an active delete operation
                    all_complete = True
                    if (
                        response
                        and response["mutatedEntities"]
                        and response["mutatedEntities"]["DELETE"]
                    ):
                        result_list = response["mutatedEntities"]["DELETE"]
                        for status in [x["status"] for x in result_list]:
                            if status == "ACTIVE":
                                # found one
                                all_complete = False
                                break

                    delete_in_progress = not all_complete
                    # sleep until next retry
                    if delete_in_progress:
                        self.logger.warning(
                            f"Deleting assets for {collection_name} still on-going."
                            "Checking again in 2 seconds..."
                        )
                        time.sleep(2)

    def _delete_sources_from_collection(
        self, collection_name: str, datasource_helper: DataSourceHelper
    ):
        """
        Deletes all sources from a given collection
        """
        self.logger.info(f"Deleting all data sources from collection {collection_name}")
        all_sources = datasource_helper.get_data_sources()
        for source in all_sources:  # type: ignore
            found_collection_name = (
                source.get("properties", {}).get("collection", {}).get("referenceName")
            )
            if found_collection_name.lower() == collection_name.lower():
                data_source_name = source.get("name")
                datasource_helper.delete_data_source(data_source_name=data_source_name)

    def get_collection_assets_by_types(
        self, collection_name: str, data_types: list, include_child: bool = False
    ):
        """
        Gets all assets of specific types in a collection and optionally subcollections.
        """
        if not self.get_collection(collection_name):
            self._logger.error(f"Collection {collection_name} not found")
            return

        asset_list = list()
        for data_type in data_types:
            if include_child:
                asset_list.extend(
                    self._get_assets_recursively(collection_name, data_type)
                )
            else:
                asset_list.extend(self._get_assets(collection_name, data_type))
        return asset_list

    def _get_assets_recursively(
        self, collection_name: str, asset_type: str = ""
    ) -> List:
        """
        Gets all assets in a collection recursively.
        If asset_type is specified, then it gets all the assets of that type
        in the collection recursively.
        """
        result_list = list()
        children = self.get_children(collection_name)
        for child in children:
            child_list = self._get_assets_recursively(child, asset_type)
            result_list.extend(child_list)

        current_list = self._get_assets(collection_name, asset_type)
        result_list.extend(current_list)
        return result_list

    def _get_collection_hierarchy(self, assets: List) -> Dict:
        """
        construct a dictionary with all the collections that
        must exist and the assets that should move to them.
        This is only for sql assets and is dependent on the schema information

        Example output:
        {
            "v1" : ["id1", "id2" ],
            "v2" : ["id3" ]
        }
        """
        collections = dict()

        for asset in assets:
            schema_name = AssetHelper.get_database_schema(asset)
            if schema_name:
                self.logger.info(f"Moving {asset['qualifiedName']} to {schema_name}")
                if schema_name not in collections:
                    collections[schema_name] = list()

                collections[schema_name].append(asset["id"])

        return collections

    def _organize_items_in_collection_hierarchy(
        self, collection_hierarchy: Dict, top_collection_name: str
    ):
        """
        Takes a dictionary of collections and items and performs the necessary moves.

        Params:
            collection_hiearchy: Dict
                Key: collection-name
                Value: list of asset Ids
            top_collection_name: str
        """
        for collection_name in collection_hierarchy.keys():
            collection = dict()
            # for all entries in dict we need to make sure the collection exists
            collection = self.create_collection(
                collection_name=collection_name,
                parent_collection_name=top_collection_name,
            )

            # move items to collection
            actual_collection_name = collection["name"]
            move_request = {"entityGuids": collection_hierarchy[collection_name]}

            self._catalog_client.collection.move_entities_to_collection(
                actual_collection_name, move_request
            )
