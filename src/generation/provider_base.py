from __future__ import annotations
from abc import ABC, abstractmethod
from src.models import GeneratedItem
from src.config import Settings

class ProviderBase(ABC):
    @abstractmethod
    def generate_one(self, settings: Settings) -> GeneratedItem:
        raise NotImplementedError
