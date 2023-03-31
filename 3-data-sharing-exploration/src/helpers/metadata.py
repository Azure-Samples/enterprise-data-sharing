from dataclasses import dataclass, field
from typing import List, Optional

from dataclasses_json import config, dataclass_json


@dataclass_json
@dataclass
class Column:
    name: str
    description: Optional[str] = None
    sensitivity: Optional[str] = field(
        metadata=config(field_name="sensitivity"), default=""
    )
    data_type: str = field(metadata=config(field_name="type"), default="")


@dataclass_json
@dataclass
class Table:
    name: str
    columns: List[Column]
    description: Optional[str] = None
    sensitivity: Optional[str] = field(
        metadata=config(field_name="sensitivity"), default=""
    )


@dataclass_json
@dataclass
class Metadata:

    version: str
    path: str
    tables: List[Table]

    @property
    def major_version_identifier(self):
        return f"v{self.version.split('.')[0]}"


@dataclass_json
@dataclass
class MetadataFile:

    container: str
    metadata_json: str

    @staticmethod
    def as_metadata_file(json: dict):
        """
        Converts a dictionary to a `MetadataFile` object.

        Parameters
        ----------
        json : dict
            Dictionary to convert to `MetadataFile`.

        Returns
        -------
        MetadataFile
            `MetadataFile` object.
        """
        return MetadataFile(json["container_name"], json["metadata_json"])
