from __future__ import annotations
import json

SYSTEM_STYLE = """You are a Spanish tutor that writes natural, grammatically correct Spanish sentences for learners.
You always follow the user's constraints and return ONLY valid JSON (no markdown, no extra text).
The Spanish MUST be fully conjugated and idiomatic (native-like), not literal or awkward.
"""

def build_prompt(
    verb: str,
    level: str,
    tense_options: list[str],
    include_questions: bool,
    include_negations: bool,
    vocab: dict
) -> str:
    return json.dumps(
        {
            "task": "Generate exactly ONE Spanish sentence that uses the given verb (in a correctly conjugated form) and provide a natural English translation.",
            "inputs": {
                "verb_infinitive": verb,
                "level": level,
                "allowed_tenses": tense_options,
                "variation": {
                    "allow_question": include_questions,
                    "allow_negation": include_negations
                },
                "vocab_hints": vocab
            },
            "hard_requirements": [
                "Output MUST be valid JSON ONLY. No markdown. No commentary outside JSON.",
                "Spanish MUST be grammatically correct: correct conjugation, agreement, accents, and word order.",
                "The verb must appear in the Spanish sentence in a conjugated form that matches the chosen tense.",
                "DO NOT use the infinitive as the main verb unless grammatically required (e.g., after a conjugated verb: 'quiero llamar').",
                "Avoid awkward literal constructions like 'Yo llamar...' or English word order in Spanish.",
                "Sentence should be natural, everyday, and something a native speaker would actually say.",
                "Keep it to ONE sentence. Prefer 6–14 words unless level is C1/C2.",
                "No profanity or sexual content."
            ],
            "tense_rules": {
                "present": "Use present indicative (e.g., 'llamo', 'comes', 'vive').",
                "preterite": "Use pretérito indefinido (e.g., 'llamé', 'comiste', 'vivió').",
                "imperfect": "Use pretérito imperfecto (e.g., 'llamaba', 'comías', 'vivía').",
                "future": "Use simple future (e.g., 'llamaré', 'comerás', 'vivirá').",
                "present_perfect": "Use 'haber' (he/has/ha/hemos/han) + past participle (e.g., 'he llamado').",
                "near_future": "Use 'ir' (voy/vas/va/vamos/van) + a + infinitive (e.g., 'voy a llamar')."
            },
            "quality_checks": [
                "Spanish sounds natural to a native speaker.",
                "English is a natural translation (not word-for-word).",
                "Chosen tense matches the Spanish verb form.",
                "No missing conjugation."
            ],
            "output_schema": {
                "verb": "string (the infinitive verb you were given)",
                "tense": "string (one of allowed_tenses)",
                "level": "string (same as input level)",
                "spanish": "string (one sentence, natural Spanish)",
                "english": "string (natural English translation)",
                "notes": "string | null (optional short note, max 120 chars)"
            },
            "examples_of_good_output": [
                {
                    "verb": "llamar",
                    "tense": "present",
                    "level": "A1",
                    "spanish": "Te llamo después de la reunión.",
                    "english": "I’ll call you after the meeting.",
                    "notes": None
                },
                {
                    "verb": "aprender",
                    "tense": "present",
                    "level": "A2",
                    "spanish": "Estoy aprendiendo español poco a poco.",
                    "english": "I’m learning Spanish little by little.",
                    "notes": "Present progressive: estar + gerund."
                }
            ]
        },
        ensure_ascii=False
    )
