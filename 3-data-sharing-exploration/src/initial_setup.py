import logging

from helpers.config import Configuration
from helpers.sql import SqlHelper

# setup logging
log_level = logging.WARNING
logging.basicConfig(
    level=log_level, format="[%(asctime)s] %(levelname)s :: %(name)s :: %(message)s"
)


def main():

    # This script should run after deployment in the context of the user (not the SP).

    config = Configuration()
    # Create SQL Helper using AZ CLI Credential instead of service principal.
    synapse = SqlHelper(config, database="master", use_cli_credentials=True)

    # Existing Service Principal - using fixed name just for test.
    synapse.create_login(config.azure_client_name)
    synapse.create_database(config.synapse_database)
    synapse.create_db_user(user_name=config.azure_client_name, role="db_owner")

    print("Login and DB User for Service Principal have been created.")

    # Purview
    synapse.create_login(config.purview_account_name)
    synapse.create_db_user(user_name=config.purview_account_name, role="db_datareader")

    print("Login and DB User for Purview have been created.")

    # Default Security Groups
    # 'role' is not assigned because permissions are handled by data_security scripts.
    synapse.create_login(config.data_security_group_low)
    synapse.create_db_user(config.data_security_group_low)

    synapse.create_login(config.data_security_group_medium)
    synapse.create_db_user(config.data_security_group_medium)

    synapse.create_login(config.data_security_group_high)
    synapse.create_db_user(config.data_security_group_high)

    print("Logins and DB Users for Security Groups have been created.")


if __name__ == "__main__":

    main()
