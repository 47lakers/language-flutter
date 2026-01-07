from __future__ import annotations
import json
import random
from openai import OpenAI
from src.config import Settings
from src.models import GeneratedItem
from src.generation.provider_base import ProviderBase
from src.generation.prompts import SYSTEM_STYLE, build_prompt

from pathlib import Path

DATA_DIR = Path(__file__).resolve().parents[1] / "data"

def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))

class OpenAIProvider(ProviderBase):
    def __init__(self, base_settings: Settings):
        self.base_settings = base_settings
        self.client = OpenAI(api_key=base_settings.openai_api_key)

        verbs = load_json(DATA_DIR / "verbs_top100.json")["verbs"]
        self.verbs: list[str] = verbs

        self.vocab: dict = load_json(DATA_DIR / "vocab.json")

    def generate_one(self, settings: Settings) -> GeneratedItem:
        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY not set")

        verb = random.choice(self.verbs)
        prompt = build_prompt(
            verb=verb,
            level=settings.app_level,
            tense_options=settings.app_tenses,
            include_questions=settings.include_questions,
            include_negations=settings.include_negations,
            vocab=self.vocab
        )

        # OpenAI Responses API (recommended for new projects) :contentReference[oaicite:1]{index=1}
        resp = self.client.responses.create(
            model=settings.openai_model,
            reasoning={"effort": settings.openai_reasoning_effort},
            instructions=SYSTEM_STYLE,
            input=prompt
        )

        text = resp.output_text.strip()
        data = json.loads(text)

        return GeneratedItem(
            verb=data["verb"],
            tense=data["tense"],
            level=data["level"],
            spanish=data["spanish"],
            english=data["english"],
            notes=data.get("notes")
        )
