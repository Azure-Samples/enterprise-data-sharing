import logging

from helpers.datacatalog.data_catalog_steps import (
    create_collection,
    create_data_source,
    create_scan_definition,
    organize_collection,
    trigger_scan,
    update_purview_asset_metadata,
)
from helpers.config import Configuration

# setup logging
log_level = logging.WARNING
logging.basicConfig(
    level=log_level, format="[%(asctime)s] %(levelname)s :: %(name)s :: %(message)s"
)


def main():

    # Initialize config
    config = Configuration()

    # Create collection in Purview
    collection_name = config.purview_collection_name
    create_collection(config)

    # Register data source in Purview
    data_source_name = f"AdventureWorks-{config.synapse_workspace_name}"
    create_data_source(data_source_name, config)

    # Create a scan definition for the database
    scan_name = "AdventureWorks_scan"
    create_scan_definition(data_source_name, scan_name, config)

    # Trigger the scan and wait for completion
    trigger_scan(data_source_name, scan_name, config)

    # Update Purview assets with metadata
    update_purview_asset_metadata(config)

    # organize collection - creates sub collections for each schema
    organize_collection(collection_name, config)
    print("All Done!")


if __name__ == "__main__":
    main()
