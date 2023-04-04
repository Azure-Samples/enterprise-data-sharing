import logging

from helpers.config import Configuration
from helpers.const import CONST
from helpers.datasecurity.data_security_common import DataSecurityCommon
from helpers.datasecurity.data_security_storage import DataSecurityStorage
from helpers.datasecurity.data_security_synapse import DataSecuritySynapse
from helpers.metadata import Metadata
from helpers.storage import StorageHelper

# setup logging
log_level = logging.ERROR
logging.basicConfig(
    level=log_level, format="[%(asctime)s] %(levelname)s :: %(name)s :: %(message)s"
)


def main():
    # setting up data security
    config = Configuration()
    storage_helper = StorageHelper(config.storage_account_name)
    data_security = DataSecurityCommon(config)
    data_security_storage = DataSecurityStorage(config)
    data_security_synapse = DataSecuritySynapse(config)
    container = config.container_name

    security_attribute = data_security.get_data_security_attribute()
    print(f"Attribute used to apply security: {security_attribute}")

    # 1. Assign the security managed attribute to all items in Purview
    data_security_synapse.assign_managed_attribute_for_security(
        security_attribute=security_attribute
    )

    all_security_groups_acls = {}
    metadata_files = storage_helper.get_metadata_files(container)
    for metadata_file in metadata_files:
        path = Metadata.from_json(metadata_file.metadata_json).path
        print(f"... Applying security to Views in {container}/{path} ...")

        # 2 . Get the value of all views' security attributes from Purview
        assigned_security_groups = data_security.get_security_for_views(
            metadata_as_json=metadata_file.metadata_json,
            m_attribute_group=CONST.MANAGED_ATTRIBUTE_GROUP,
            m_attribute_name=CONST.SECURITY_GROUP_MANAGED_ATTRIBUTE_NAME,
        )
        print("Security Groups assigned to Views retrieved from from Purview.")
        print(assigned_security_groups)

        # 3. Generate GRANT statements and apply security to Synapse assets
        data_security_synapse.apply_security_to_synpase_assets(
            assigned_security_groups, path
        )

        print(f"Applied security to synapse assets for {path}")

        # 4. Apply ACL to all folders/files
        applied_acls = data_security_storage.apply_acl_to_storage_for_security(
            container=container,
            path=path,
            assigned_security_groups=assigned_security_groups,
        )
        print(
            f"ACL Applied to files and directories in {path}: "
            f"{list(applied_acls.keys())}"
        )
        all_security_groups_acls.update(applied_acls)

    # 5. Apply ACL to root dir so that all groups have access
    comma_separated_acl_list = ",".join(all_security_groups_acls.values())
    data_security_storage.apply_acl_to_directory(
        file_system_path=container,
        directory="/",
        acl=comma_separated_acl_list,
    )
    print(f"ACL applied to root directory: {list(all_security_groups_acls.keys())}")


if __name__ == "__main__":

    main()
