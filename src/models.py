from __future__ import annotations
from pydantic import BaseModel, Field

class GeneratedItem(BaseModel):
    verb: str
    tense: str
    level: str
    spanish: str
    english: str
    notes: str | None = None
