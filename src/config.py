from __future__ import annotations
from pydantic import BaseModel, Field
from dotenv import load_dotenv
import os

load_dotenv()

class Settings(BaseModel):
    # OpenAI
    openai_api_key: str | None = Field(default_factory=lambda: os.getenv("OPENAI_API_KEY"))
    openai_model: str = Field(default_factory=lambda: os.getenv("OPENAI_MODEL", "gpt-5-mini"))
    openai_reasoning_effort: str = Field(default_factory=lambda: os.getenv("OPENAI_REASONING_EFFORT", "low"))

    # App generation defaults
    app_level: str = Field(default_factory=lambda: os.getenv("APP_LEVEL", "A2"))
    app_tenses_raw: str = Field(default_factory=lambda: os.getenv("APP_TENSES", "present,preterite"))
    include_questions: bool = False
    include_negations: bool = False

    # TTS
    app_tts_voice_es: str = Field(default_factory=lambda: os.getenv("APP_TTS_VOICE_ES", "es-ES-ElviraNeural"))
    app_tts_voice_en: str = Field(default_factory=lambda: os.getenv("APP_TTS_VOICE_EN", "en-US-JennyNeural"))

    @property
    def app_tenses(self) -> list[str]:
        return [t.strip() for t in self.app_tenses_raw.split(",") if t.strip()]
