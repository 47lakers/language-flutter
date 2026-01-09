from __future__ import annotations

import json
import random
from pathlib import Path
from typing import Any

import google.genai as genai

from src.config import Settings
from src.models import GeneratedItem
from src.generation.provider_base import ProviderBase
from src.generation.template_fallback import TemplateFallbackGenerator
from src.generation.prompts import SYSTEM_STYLE, build_prompt

DATA_DIR = Path(__file__).resolve().parents[1] / "data"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


class GeminiProvider(ProviderBase):
    """Provider that integrates with the new `google.genai` package."""

    def __init__(self, base_settings: Settings):
        self.base_settings = base_settings
        self.api_key = base_settings.gemini_api_key
        self.model = base_settings.gemini_model

        verbs = load_json(DATA_DIR / "verbs_top100.json")["verbs"]
        self.verbs: list[str] = verbs

        self.vocab: dict = load_json(DATA_DIR / "vocab.json")
        self._template_fallback = TemplateFallbackGenerator(base_settings)

    def _generate_with_model(self, input_text: str) -> Any:
        """Call the model using the google.genai Client API."""
        try:
            # The new google.genai uses a Client-based API
            client = genai.Client(api_key=self.api_key)
            
            # Try to generate content using the client
            # The API structure is client.models.generate_content()
            response = client.models.generate_content(
                model=self.model,
                contents=input_text
            )
            return response
        except Exception as e:
            print(f"Error calling client.models.generate_content: {e}")
            return None

    def _extract_text(self, resp: Any) -> str | None:
        """Robustly extract textual output from the response object."""
        if resp is None:
            return None

        # Try common response attributes first
        for attr in ("text", "content"):
            val = getattr(resp, attr, None)
            if val and isinstance(val, str):
                return val.strip()

        # Try candidates (common in genai responses)
        candidates = getattr(resp, "candidates", None)
        if candidates and isinstance(candidates, list) and len(candidates) > 0:
            first_candidate = candidates[0]
            
            # Try content.parts pattern
            content = getattr(first_candidate, "content", None)
            if content:
                parts = getattr(content, "parts", None)
                if parts and isinstance(parts, list):
                    text_parts = []
                    for part in parts:
                        # part might have .text attribute
                        text = getattr(part, "text", None)
                        if text:
                            text_parts.append(str(text))
                    if text_parts:
                        return "".join(text_parts).strip()

        # Try to access response as dict
        if isinstance(resp, dict):
            # Try candidates key
            if "candidates" in resp and isinstance(resp["candidates"], list):
                cands = resp["candidates"]
                if cands:
                    first = cands[0]
                    if isinstance(first, dict):
                        content = first.get("content", {})
                        if isinstance(content, dict):
                            parts = content.get("parts", [])
                            if parts:
                                text_parts = []
                                for part in parts:
                                    if isinstance(part, dict) and "text" in part:
                                        text_parts.append(part["text"])
                                    elif isinstance(part, str):
                                        text_parts.append(part)
                                if text_parts:
                                    return "".join(text_parts).strip()

        # Fallback: try string representation
        try:
            s = str(resp).strip()
            if s and not s.startswith("<"):  # Avoid printing object repr
                return s
        except Exception:
            pass
        
        return None

    def generate_one(self, settings: Settings) -> GeneratedItem:
        if not settings.gemini_api_key:
            # no API key; use safe fallback
            return self._template_fallback.generate_one(settings=settings)

        verb = random.choice(self.verbs)
        prompt = build_prompt(
            verb=verb,
            level=settings.app_level,
            tense_options=settings.app_tenses,
            include_questions=settings.include_questions,
            include_negations=settings.include_negations,
            vocab=self.vocab,
            batch_size=settings.batch_size,
        )

        input_text = f"{SYSTEM_STYLE}\n\n{prompt}"

        resp = self._generate_with_model(input_text=input_text)
        if resp is None:
            # Fall back and keep the app working
            print("Warning: could not call google.genai client; falling back to template generator.")
            return self._template_fallback.generate_one(settings=settings)

        text = self._extract_text(resp)
        if not text:
            # nothing extracted; fall back
            print("Warning: unexpected response shape from generative client; falling back to template generator.")
            return self._template_fallback.generate_one(settings=settings)

        # Expect the model to return strict JSON as instructed in the prompt.
        try:
            # Strip markdown code fences if present
            cleaned_text = text.strip()
            if cleaned_text.startswith("```"):
                # Remove leading ```json or ``` 
                cleaned_text = cleaned_text.split("```", 1)[1]  # Remove first ```
                if cleaned_text.startswith("json\n"):
                    cleaned_text = cleaned_text[5:]  # Remove "json\n"
                elif cleaned_text.startswith("json"):
                    cleaned_text = cleaned_text[4:]  # Remove "json"
                # Remove trailing ```
                if cleaned_text.endswith("```"):
                    cleaned_text = cleaned_text.rsplit("```", 1)[0]
            
            data = json.loads(cleaned_text)
        except Exception as e:
            # If the model didn't return JSON, fall back
            print(f"Warning: model output was not valid JSON: {e}")
            return self._template_fallback.generate_one(settings=settings)

        # Handle batch response
        if settings.batch_size > 1 and "sentences" in data:
            # Return the first item from the batch; rest are cached separately
            if isinstance(data["sentences"], list) and len(data["sentences"]) > 0:
                item_data = data["sentences"][0]
            else:
                print("Warning: batch returned empty sentences; falling back to template generator.")
                return self._template_fallback.generate_one(settings=settings)
        else:
            item_data = data

        return GeneratedItem(
            verb=item_data.get("verb", ""),
            tense=item_data.get("tense", ""),
            level=item_data.get("level", ""),
            spanish=item_data.get("spanish", ""),
            english=item_data.get("english", ""),
            notes=item_data.get("notes"),
        )

    def generate_batch(self, settings: Settings, focus_verbs: list[str] | None = None) -> list[GeneratedItem]:
        """Generate a batch of sentences in a single API call.
        
        If focus_verbs is provided, all sentences will use verbs from that list
        (distributed evenly across the verbs).
        Otherwise, a random verb is chosen for all sentences in the batch.
        """
        if not settings.gemini_api_key:
            # no API key; use safe fallback
            return [self._template_fallback.generate_one(settings=settings) for _ in range(settings.batch_size)]

        # Use focus verbs or pick a random one
        if focus_verbs and len(focus_verbs) > 0:
            verb_list = focus_verbs
        else:
            verb_list = [random.choice(self.verbs)]
        
        prompt = build_prompt(
            verb=verb_list,  # pass list of verbs
            level=settings.app_level,
            tense_options=settings.app_tenses,
            include_questions=settings.include_questions,
            include_negations=settings.include_negations,
            vocab=self.vocab,
            batch_size=settings.batch_size,
        )

        input_text = f"{SYSTEM_STYLE}\n\n{prompt}"

        resp = self._generate_with_model(input_text=input_text)
        if resp is None:
            # Fall back and keep the app working
            print("Warning: could not call google.genai client; falling back to template generator.")
            return [self._template_fallback.generate_one(settings=settings) for _ in range(settings.batch_size)]

        text = self._extract_text(resp)
        if not text:
            # nothing extracted; fall back
            print("Warning: unexpected response shape from generative client; falling back to template generator.")
            return [self._template_fallback.generate_one(settings=settings) for _ in range(settings.batch_size)]

        # Expect the model to return strict JSON as instructed in the prompt.
        try:
            # Strip markdown code fences if present
            cleaned_text = text.strip()
            if cleaned_text.startswith("```"):
                # Remove leading ```json or ``` 
                cleaned_text = cleaned_text.split("```", 1)[1]  # Remove first ```
                if cleaned_text.startswith("json\n"):
                    cleaned_text = cleaned_text[5:]  # Remove "json\n"
                elif cleaned_text.startswith("json"):
                    cleaned_text = cleaned_text[4:]  # Remove "json"
                # Remove trailing ```
                if cleaned_text.endswith("```"):
                    cleaned_text = cleaned_text.rsplit("```", 1)[0]
            
            data = json.loads(cleaned_text)
        except Exception as e:
            # If the model didn't return JSON, fall back
            print(f"Warning: model output was not valid JSON: {e}")
            print(f"Raw text returned: {text[:500]}")  # Print first 500 chars for debugging
            return [self._template_fallback.generate_one(settings=settings) for _ in range(settings.batch_size)]

        # Parse batch response
        items = []
        sentences_data = data.get("sentences", [])
        if not isinstance(sentences_data, list):
            sentences_data = [data]  # fallback to single response

        for item_data in sentences_data:
            items.append(
                GeneratedItem(
                    verb=item_data.get("verb", ""),
                    tense=item_data.get("tense", ""),
                    level=item_data.get("level", ""),
                    spanish=item_data.get("spanish", ""),
                    english=item_data.get("english", ""),
                    notes=item_data.get("notes"),
                )
            )

        return items
