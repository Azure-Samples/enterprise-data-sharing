import sys
from pprint import pprint
from time import sleep

from helpers.const import CONST
from helpers.config import Configuration
from helpers.metadata import Metadata
from helpers.purview.catalog import CatalogHelper
from helpers.purview.collections import CollectionHelper
from helpers.purview.datasources import DataSourceHelper
from helpers.purview.managed_attributes import ManagedAttributesHelper
from helpers.purview.scans import ScanHelper
from helpers.storage import StorageHelper


def create_collection(config: Configuration):
    """Create a collection to store Synapse assets if it does not exist"""
    collection_helper = CollectionHelper(config)
    print(f"Checking if collection {config.purview_collection_name} exists...")

    collection = collection_helper.get_collection(config.purview_collection_name)
    if collection is None:
        print(f"Collection {config.purview_collection_name} not found. Creating...")
        collection = collection_helper.create_collection(config.purview_collection_name)
    print("Collection details:")
    pprint(collection)


def create_data_source(data_source_name: str, config: Configuration):
    """Create the Synapse data source and assign it to the collection"""
    data_source_helper = DataSourceHelper(config)
    print(f"Checking if data source {data_source_name} exists...")
    data_source = data_source_helper.get_data_source(data_source_name)
    if data_source is None:
        print(f"Data source {data_source_name} does not exist. Creating...")
        data_source_helper.register_synapse_data_source(
            collection_name=config.purview_collection_name,
            data_source_name=data_source_name,
            resource_group_name=config.resource_group_name,
            location=config.azure_location,
            workspace_name=config.synapse_workspace_name,
            subscription_id=config.azure_subscription_id,
        )
        print(f"Data source {data_source_name} registered!")


def create_scan_definition(
    data_source_name: str, scan_name: str, config: Configuration
):
    """Create the synapse scan definition and assign it to the correct data source"""
    scan_helper = ScanHelper(config)
    scan_helper.create_synapse_scan_definition(
        data_source_name=data_source_name,
        scan_name=scan_name,
        collection_name=config.purview_collection_name,
        db_names=[config.synapse_database],
    )
    print(f"Scan definition {scan_name} created")


def trigger_scan(data_source_name: str, scan_name: str, config: Configuration):
    """Triggers the scan and waits for completion"""

    print("Checking if any scans are running on this data source...")
    scan_helper = ScanHelper(config)
    scan_history = scan_helper.get_scan_history(
        data_source_name=data_source_name, scan_name=scan_name
    )
    if scan_history:
        for run in scan_history:
            run_id = run["id"]
            if not scan_helper.check_scan_run_is_complete(
                run_id=run_id,
                data_source_name=data_source_name,
                scan_name=scan_name,
            ):
                print(
                    "A previous scan is still executing. Please wait for it to complete"
                    " and retry the script"
                )
                sys.exit()

    print("Triggering synapse data source scan...")
    trigger_scan_result = scan_helper.trigger_scan(
        data_source_name=data_source_name, scan_name=scan_name
    )
    if trigger_scan_result:
        print("Scan trigger result:")
        pprint(trigger_scan_result)

    # Wait for the scan to complete
    print("Waiting for scan to complete...")
    scan_is_complete = False
    while not scan_is_complete:
        print("Checking...")
        scan_is_complete = scan_helper.check_scan_run_is_complete(
            trigger_scan_result["scanResultId"],
            data_source_name=data_source_name,
            scan_name=scan_name,
        )
        sleep(10)

    print("Scan complete!")


def update_purview_asset_metadata(config: Configuration):
    """Updates purview scanned assets using the metadata files"""

    storage_helper = StorageHelper(config.storage_account_name)
    catalog_helper = CatalogHelper(config)
    managed_attribute_helper = ManagedAttributesHelper(config)

    # get all metadata files
    metadata_files = storage_helper.get_metadata_files(config.adls_container_name)

    # to determine the fully qualified name of the star schema tables in synapse
    # we need to know which database and schema they belong to
    synapse_workspace = config.synapse_workspace_name
    server_name = f"{synapse_workspace}-ondemand.sql.azuresynapse.net"
    database_name = config.synapse_database
    managed_attribute_group = config.security_managed_attribute_group
    managed_attribute = config.data_security_attribute

    # We need to create a managed attribute group and manged attribute first
    managed_attribute_helper.add_m_attribute_group(managed_attribute_group)
    managed_attribute_helper.add_m_attribute_to_attribute_group(
        managed_attribute_group, managed_attribute
    )

    for metadata_file in metadata_files:
        metadata = Metadata.from_json(metadata_file.metadata_json)
        schema_name = (
            f"{metadata.major_version_identifier}_{config.synapse_database_schema}"
        )

        for table in metadata.tables:
            print(f"Updating table {table.name}")
            # construct fully qualified name for table
            table_qualified_name = (
                catalog_helper.get_synapse_table_fully_qualified_name(
                    server_name=server_name,
                    database_name=database_name,
                    schema_name=schema_name,
                    table_name=table.name,
                )
            )
            # fetch asset from Purview catalog
            table_entity = catalog_helper.get_asset_by_fully_qualified_name(
                qualified_name=table_qualified_name,
                type_name=CONST.PURVIEW_SYNAPSE_SQL_VIEW_DATA_TYPE,
            )
            if not table_entity:
                print(f"Skipping {table.name}...")
                continue

            # extract the entity id for the table
            table_guid = catalog_helper.get_entity_id_from_asset(table_entity)

            # update table metadata in Purview
            catalog_helper.set_attribute(
                entity_id=table_guid,
                attribute_name="description",
                attribute_value=table.description,
            )

            if table.sensitivity:
                managed_attribute_helper.update_m_attribute(
                    entity_id=table_guid,
                    m_attribute_group=managed_attribute_group,
                    m_attribute_name=managed_attribute,
                    m_attribute_value=table.sensitivity,
                )

            for column in table.columns:
                print(f"\tUpdating column {column.name}")
                # construct fully qualified name for column
                column_qualified_name = table_qualified_name + f"#{column.name}"
                column_entity = catalog_helper.get_asset_by_fully_qualified_name(
                    qualified_name=column_qualified_name,
                    type_name="azure_synapse_serverless_sql_view_column",
                )
                if not column_entity:
                    print(f"\tSkipping {column.name}...")
                    continue

                # extract the entity id for the column
                column_guid = catalog_helper.get_entity_id_from_asset(column_entity)

                catalog_helper.set_attribute(
                    entity_id=column_guid,
                    attribute_name="description",
                    attribute_value=column.description,
                )

                if column.sensitivity:
                    managed_attribute_helper.update_m_attribute(
                        entity_id=column_guid,
                        m_attribute_group=managed_attribute_group,
                        m_attribute_name=managed_attribute,
                        m_attribute_value=column.sensitivity,
                    )


def organize_collection(collection_name: str, config: Configuration):
    """
    Organizes a purview collection by separating sql assets
    in child collections depending on schema
    """
    collection_helper = CollectionHelper(config)
    collection_helper.organize_collection(collection_name)
