import logging

from helpers.config import Configuration
from helpers.purview.collections import CollectionHelper
from helpers.sql import SqlHelper

# setup logging
log_level = logging.WARNING
logging.basicConfig(
    level=log_level, format="[%(asctime)s] %(levelname)s :: %(name)s :: %(message)s"
)


def main():

    # initialize config
    config = Configuration()

    # Delete Purview collection
    collection_helper = CollectionHelper(config)
    print(f"Cleaning up {config.purview_collection_name} collection...")
    collection_helper.cleanup_collection(config.purview_collection_name)

    # Delete created views in synapse database
    try:
        sql_helper = SqlHelper(config)
        print(f"Dropping views from {config.synapse_database}...")
        sql_helper.drop_all_views()
    except Exception as ex:
        logging.error(f"Error: {ex}")

    answer = input(
        "Do you also want to delete the database? You will need to re-run initial_setup.py to recreate it. (y/n):"
    )
    if answer.lower() == "y":
        try:
            sql_helper = SqlHelper(config, database="master")
            print("Dropping database...")
            sql_helper.drop_database(config.synapse_database)
        except Exception as ex:
            logging.error(f"Error: {ex}")
    print("Done!")


if __name__ == "__main__":
    main()
