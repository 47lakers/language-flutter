from src.config import Settings
from src.models import GeneratedItem
from src.generation.fallback_top10 import generate_one as gen_top10

class TemplateFallbackGenerator:
    def __init__(self, settings: Settings):
        self.settings = settings

    def generate_one(self, settings: Settings) -> GeneratedItem:
        item = gen_top10(
            level=settings.app_level,
            allowed_tenses=settings.app_tenses
        )

        return GeneratedItem(
            verb=item.verb,
            tense=item.tense,
            level=item.level,
            spanish=item.spanish,
            english=item.english,
            notes=item.notes,
        )
