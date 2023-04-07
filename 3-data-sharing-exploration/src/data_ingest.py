import logging

from helpers.config import Configuration
from helpers.sql import SqlHelper
from helpers.storage import StorageHelper

# setup logging
log_level = logging.WARNING
logging.basicConfig(
    level=log_level, format="[%(asctime)s] %(levelname)s :: %(name)s :: %(message)s"
)


def main():
    # setting up storage access
    config = Configuration()
    storage = StorageHelper(config.storage_account_name)
    # setting up synapse access
    synapse = SqlHelper(config)

    container = config.adls_container_name
    # listing metadata files
    metadata_files = storage.get_metadata_files(container)
    found = len(metadata_files)
    print(f"Found {found} metadata files")

    # create all views
    for metadata_file in metadata_files:
        synapse.create_views_from_metadata(
            metadata_as_json=metadata_file.metadata_json,
            schema=config.synapse_database_schema,
        )

    # test that views have been created
    result = synapse.list_views()
    print(result)


if __name__ == "__main__":

    main()
