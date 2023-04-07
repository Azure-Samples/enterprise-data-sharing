"""
Purview Managed Attributes helper functions
"""
import json
import logging

# pyright: reportMissingTypeStubs=false
from typing import Any, Union

import requests
from azure.core.exceptions import HttpResponseError
from azure.purview.catalog import PurviewCatalogClient

from ..config import Configuration
from .clients import ClientHelper

JSONType = Any


class ManagedAttributesHelper:

    _catalog_client: PurviewCatalogClient
    _configuration: Configuration

    def __init__(self, configuration: Configuration):
        self._configuration = configuration
        self.logger = logging.getLogger(__name__)
        purviewhelper = ClientHelper(account_name=configuration.purview_account_name)
        self._catalog_client = purviewhelper.get_catalog_client()
        self._endpoint = (
            f"https://{self._configuration.purview_account_name}.purview.azure.com"
        )

    def _get_token(self) -> str:
        """
        Get token to enable API calls
        """
        url = f"https://login.microsoftonline.com/{self._configuration.azure_tenant_id}/oauth2/token"
        headers = {"Content-Type": "application/x-www-form-urlencoded"}
        params = "client_id={id}&client_secret={secret}&grant_type={grant_type}&resource={resource}".format(
            id=self._configuration.azure_client_id,
            secret=self._configuration.azure_client_secret,
            grant_type="client_credentials",
            resource="https://purview.azure.net",
        )

        response = requests.post(
            url,
            headers=headers,
            data=params,
        )

        try:
            access_token = response.json().get("access_token")
        except Exception as e:
            self.logger.error("Access token could not be retrieved correctly", e)
            raise Exception("Access token could not be retrieved correctly.", e)

        return access_token

    def get_entity_by_guid(self, guid: str):
        """
        Get an entity by guid
        """
        try:
            response = self._catalog_client.entity.get_by_guid(guid)  # type: ignore
            return response

        except (ValueError, HttpResponseError) as ex:
            self.logger.error(ex)

    def get_m_attribute_value(
        self, m_attribute_name: str, m_attribute_group: str, entity_id: str
    ):
        """
        Get the value of the managed attribute by attribute name, group and entity id
        """
        entity = self.get_entity_by_guid(entity_id)
        if entity:
            try:
                return entity["entity"]["businessAttributes"][m_attribute_group][
                    m_attribute_name
                ]
            except KeyError:
                self.logger.info(
                    f"The entity does not contain the attribute: {m_attribute_group}"
                )
                return

    def update_m_attribute(
        self,
        entity_id: str,
        m_attribute_group: str,
        m_attribute_name: str,
        m_attribute_value: Any,
    ):
        """
        Updates the value of the managed attribute for the entity

        Parameters
        ----------
        entity_id: str
            GUID of the entity to update

        m_attribute_group: str
            Name of the attribute group to use for the update. E.g. "Metadata"

        m_attribute_name: str
            Name of the managed attribute to update. E.g. "Sensitivity"

        m_attribute_value: Any
            Value to update the attribute with. E.g. "low"
        """
        url = f"{self._endpoint}/catalog/api/atlas/v2/entity/guid/{entity_id}/businessmetadata/{m_attribute_group}"
        headers = {
            "Authorization": f"Bearer {self._get_token()}",
            "Content-Type": "application/json",
        }
        data = {m_attribute_name: m_attribute_value}

        response = requests.post(url=url, headers=headers, data=json.dumps(data))
        self.logger.info(response.text)
        return response

    def get_all_m_attribute_groups(self) -> list:
        """
        Get a list of all managed attribute groups
        """
        # FYI: type business_metadata is not documented and might change in the future
        url = f"{self._endpoint}/catalog/api/atlas/v2/types/typedefs?type=business_metadata"
        headers = {
            "Authorization": f"Bearer {self._get_token()}",
        }

        response = requests.get(
            url=url,
            headers=headers,
        )

        business_metadata = response.json().get("businessMetadataDefs")
        self.logger.debug(f"{business_metadata = }")
        return business_metadata

    def add_m_attribute_group(
        self,
        m_attribute_group: str,
    ) -> requests.Response:  # type: ignore
        """
        Add a new managed attribute group
        """

        business_metadata_definition = {
            "businessMetadataDefs": [
                {
                    "category": "BUSINESS_METADATA",
                    "version": 1,
                    "typeVersion": "1.1",
                    "name": m_attribute_group,
                }
            ]
        }
        url = f"{self._endpoint}/catalog/api/atlas/v2/types/typedefs"
        headers = {
            "Authorization": f"Bearer {self._get_token()}",
            "Content-Type": "application/json",
        }

        response = requests.post(
            url=url, headers=headers, data=json.dumps(business_metadata_definition)
        )
        if response.status_code != 200:
            self.logger.error(response.content)
        else:
            self.logger.info(response)

        return response

    def add_m_attribute_to_attribute_group(
        self,
        m_attribute_group: str,
        m_attribute_name: str,
        m_attribute_type: str = "string",
        **kwargs,
    ) -> requests.Response:
        """
        Add a new managed attribute to an attribute group
        """
        # To add an attribute it is necessary to get the whole metadata object
        business_metadata = self.get_all_m_attribute_groups()
        # We will have to add the attribute to the existing attributes list in the metadata that we want
        bm_attributes = []
        found = False
        for metadata in business_metadata:
            if metadata.get("name") == m_attribute_group:
                found = True
                bm_attributes = metadata.get("attributeDefs")
                break  # Once we found the metadata to update we break
        if not found:
            self.logger.error(f"No metadata found with name {m_attribute_group}")
            raise AttributeError
        attribute_options = {
            "applicableEntityTypes": '["Referenceable"]',
        }

        # Strings have a mandatory option maxStrLength
        if m_attribute_type == "string":
            attribute_options.update({"maxStrLength": kwargs.get("maxStrLength", 50)})

        new_attribute = {
            "name": m_attribute_name,
            "typeName": m_attribute_type,
            "isIndexable": True,
            "isOptional": True,
            "options": attribute_options,
        }
        bm_attributes.append(new_attribute)

        url = f"{self._endpoint}/catalog/api/atlas/v2/types/typedefs"

        headers = {
            "Authorization": f"Bearer {self._get_token()}",
            "Content-Type": "application/json",
        }

        data = {
            "businessMetadataDefs": [
                {"name": m_attribute_group, "attributeDefs": bm_attributes},
            ],
        }

        response = requests.put(url=url, headers=headers, data=json.dumps(data))
        self.logger.info(response)
        return response

    def get_all_m_attributes_per_group(
        self, m_attribute_group: str, entity_id: str
    ) -> Union[dict, None]:
        """
        Get all managed attributes in the provided group for this entity
        """
        entity = self.get_entity_by_guid(entity_id)
        if entity:
            try:
                attributes = entity["entity"]["businessAttributes"][m_attribute_group]
                return attributes
            except KeyError:
                self.logger.info(
                    f"The entity does not contain the group: {m_attribute_group}"
                )
                return None
        return None
