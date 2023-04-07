from dataclasses import dataclass
from typing import Dict, List

from dataclasses_json import dataclass_json


@dataclass_json
@dataclass
class Rule:
    constraints: Dict
    security_group: str


@dataclass_json
@dataclass
class DataSecurityFile:
    security_groups: List[str]
    rules: List[Rule]
