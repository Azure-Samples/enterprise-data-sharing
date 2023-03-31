import logging


class SynapseHelper:
    """Contains methods for interacting with Synapse"""

    def __init__(self, account_name: str):
        self._account_name = account_name
        self.logger = logging.getLogger(__name__)
        self.logger.info(f"SynapseHelper initialized with account name {account_name}")
