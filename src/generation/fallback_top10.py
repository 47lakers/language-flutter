from __future__ import annotations
import random
from dataclasses import dataclass

SUBJECTS = [
    ("yo", "1s"),
    ("tú", "2s"),
    ("él", "3s"),
    ("ella", "3s"),
    ("nosotros", "1p"),
    ("ellos", "3p"),
]

# Hand-curated conjugations for TOP 10 verbs.
# Keys: verb -> tense -> person -> form (NO subject included)
CONJ = {
    "ser": {
        "present": {"1s":"soy","2s":"eres","3s":"es","1p":"somos","3p":"son"},
        "preterite": {"1s":"fui","2s":"fuiste","3s":"fue","1p":"fuimos","3p":"fueron"},
        "imperfect": {"1s":"era","2s":"eras","3s":"era","1p":"éramos","3p":"eran"},
        "future": {"1s":"seré","2s":"serás","3s":"será","1p":"seremos","3p":"serán"},
        "present_perfect": {"1s":"he sido","2s":"has sido","3s":"ha sido","1p":"hemos sido","3p":"han sido"},
        "near_future": {"1s":"voy a ser","2s":"vas a ser","3s":"va a ser","1p":"vamos a ser","3p":"van a ser"},
    },
    "estar": {
        "present": {"1s":"estoy","2s":"estás","3s":"está","1p":"estamos","3p":"están"},
        "preterite": {"1s":"estuve","2s":"estuviste","3s":"estuvo","1p":"estuvimos","3p":"estuvieron"},
        "imperfect": {"1s":"estaba","2s":"estabas","3s":"estaba","1p":"estábamos","3p":"estaban"},
        "future": {"1s":"estaré","2s":"estarás","3s":"estará","1p":"estaremos","3p":"estarán"},
        "present_perfect": {"1s":"he estado","2s":"has estado","3s":"ha estado","1p":"hemos estado","3p":"han estado"},
        "near_future": {"1s":"voy a estar","2s":"vas a estar","3s":"va a estar","1p":"vamos a estar","3p":"van a estar"},
    },
    "tener": {
        "present": {"1s":"tengo","2s":"tienes","3s":"tiene","1p":"tenemos","3p":"tienen"},
        "preterite": {"1s":"tuve","2s":"tuviste","3s":"tuvo","1p":"tuvimos","3p":"tuvieron"},
        "imperfect": {"1s":"tenía","2s":"tenías","3s":"tenía","1p":"teníamos","3p":"tenían"},
        "future": {"1s":"tendré","2s":"tendrás","3s":"tendrá","1p":"tendremos","3p":"tendrán"},
        "present_perfect": {"1s":"he tenido","2s":"has tenido","3s":"ha tenido","1p":"hemos tenido","3p":"han tenido"},
        "near_future": {"1s":"voy a tener","2s":"vas a tener","3s":"va a tener","1p":"vamos a tener","3p":"van a tener"},
    },
    "hacer": {
        "present": {"1s":"hago","2s":"haces","3s":"hace","1p":"hacemos","3p":"hacen"},
        "preterite": {"1s":"hice","2s":"hiciste","3s":"hizo","1p":"hicimos","3p":"hicieron"},
        "imperfect": {"1s":"hacía","2s":"hacías","3s":"hacía","1p":"hacíamos","3p":"hacían"},
        "future": {"1s":"haré","2s":"harás","3s":"hará","1p":"haremos","3p":"harán"},
        "present_perfect": {"1s":"he hecho","2s":"has hecho","3s":"ha hecho","1p":"hemos hecho","3p":"han hecho"},
        "near_future": {"1s":"voy a hacer","2s":"vas a hacer","3s":"va a hacer","1p":"vamos a hacer","3p":"van a hacer"},
    },
    "ir": {
        "present": {"1s":"voy","2s":"vas","3s":"va","1p":"vamos","3p":"van"},
        "preterite": {"1s":"fui","2s":"fuiste","3s":"fue","1p":"fuimos","3p":"fueron"},
        "imperfect": {"1s":"iba","2s":"ibas","3s":"iba","1p":"íbamos","3p":"iban"},
        "future": {"1s":"iré","2s":"irás","3s":"irá","1p":"iremos","3p":"irán"},
        "present_perfect": {"1s":"he ido","2s":"has ido","3s":"ha ido","1p":"hemos ido","3p":"han ido"},
        "near_future": {"1s":"voy a ir","2s":"vas a ir","3s":"va a ir","1p":"vamos a ir","3p":"van a ir"},
    },
    "poder": {
        "present": {"1s":"puedo","2s":"puedes","3s":"puede","1p":"podemos","3p":"pueden"},
        "preterite": {"1s":"pude","2s":"pudiste","3s":"pudo","1p":"pudimos","3p":"pudieron"},
        "imperfect": {"1s":"podía","2s":"podías","3s":"podía","1p":"podíamos","3p":"podían"},
        "future": {"1s":"podré","2s":"podrás","3s":"podrá","1p":"podremos","3p":"podrán"},
        "present_perfect": {"1s":"he podido","2s":"has podido","3s":"ha podido","1p":"hemos podido","3p":"han podido"},
        "near_future": {"1s":"voy a poder","2s":"vas a poder","3s":"va a poder","1p":"vamos a poder","3p":"van a poder"},
    },
    "decir": {
        "present": {"1s":"digo","2s":"dices","3s":"dice","1p":"decimos","3p":"dicen"},
        "preterite": {"1s":"dije","2s":"dijiste","3s":"dijo","1p":"dijimos","3p":"dijeron"},
        "imperfect": {"1s":"decía","2s":"decías","3s":"decía","1p":"decíamos","3p":"decían"},
        "future": {"1s":"diré","2s":"dirás","3s":"dirá","1p":"diremos","3p":"dirán"},
        "present_perfect": {"1s":"he dicho","2s":"has dicho","3s":"ha dicho","1p":"hemos dicho","3p":"han dicho"},
        "near_future": {"1s":"voy a decir","2s":"vas a decir","3s":"va a decir","1p":"vamos a decir","3p":"van a decir"},
    },
    "ver": {
        "present": {"1s":"veo","2s":"ves","3s":"ve","1p":"vemos","3p":"ven"},
        "preterite": {"1s":"vi","2s":"viste","3s":"vio","1p":"vimos","3p":"vieron"},
        "imperfect": {"1s":"veía","2s":"veías","3s":"veía","1p":"veíamos","3p":"veían"},
        "future": {"1s":"veré","2s":"verás","3s":"verá","1p":"veremos","3p":"verán"},
        "present_perfect": {"1s":"he visto","2s":"has visto","3s":"ha visto","1p":"hemos visto","3p":"han visto"},
        "near_future": {"1s":"voy a ver","2s":"vas a ver","3s":"va a ver","1p":"vamos a ver","3p":"van a ver"},
    },
    "dar": {
        "present": {"1s":"doy","2s":"das","3s":"da","1p":"damos","3p":"dan"},
        "preterite": {"1s":"di","2s":"diste","3s":"dio","1p":"dimos","3p":"dieron"},
        "imperfect": {"1s":"daba","2s":"dabas","3s":"daba","1p":"dábamos","3p":"daban"},
        "future": {"1s":"daré","2s":"darás","3s":"dará","1p":"daremos","3p":"darán"},
        "present_perfect": {"1s":"he dado","2s":"has dado","3s":"ha dado","1p":"hemos dado","3p":"han dado"},
        "near_future": {"1s":"voy a dar","2s":"vas a dar","3s":"va a dar","1p":"vamos a dar","3p":"van a dar"},
    },
    "saber": {
        "present": {"1s":"sé","2s":"sabes","3s":"sabe","1p":"sabemos","3p":"saben"},
        "preterite": {"1s":"supe","2s":"supiste","3s":"supo","1p":"supimos","3p":"supieron"},
        "imperfect": {"1s":"sabía","2s":"sabías","3s":"sabía","1p":"sabíamos","3p":"sabían"},
        "future": {"1s":"sabré","2s":"sabrás","3s":"sabrá","1p":"sabremos","3p":"sabrán"},
        "present_perfect": {"1s":"he sabido","2s":"has sabido","3s":"ha sabido","1p":"hemos sabido","3p":"han sabido"},
        "near_future": {"1s":"voy a saber","2s":"vas a saber","3s":"va a saber","1p":"vamos a saber","3p":"van a saber"},
    },
}

# Spanish templates aligned by verb.
TEMPLATES = {
    "ser": [
        "{SUBJ} {V} de aquí.",
        "{SUBJ} {V} muy puntual.",
        "{SUBJ} {V} estudiante.",
        "{SUBJ} {V} el jefe hoy.",
    ],
    "estar": [
        "{SUBJ} {V} en casa.",
        "{SUBJ} {V} cansado hoy.",
        "{SUBJ} {V} listo.",
        "{SUBJ} {V} en una reunión.",
    ],
    "tener": [
        "{SUBJ} {V} tiempo ahora.",
        "{SUBJ} {V} una pregunta.",
        "{SUBJ} {V} hambre.",
        "{SUBJ} {V} que irme.",
    ],
    "hacer": [
        "{SUBJ} {V} ejercicio.",
        "{SUBJ} {V} la cena.",
        "{SUBJ} {V} una pausa.",
        "{SUBJ} {V} un plan.",
    ],
    "ir": [
        "{SUBJ} {V} al trabajo.",
        "{SUBJ} {V} a casa.",
        "{SUBJ} {V} al gimnasio.",
        "{SUBJ} {V} al supermercado.",
    ],
    "poder": [
        "{SUBJ} {V} ayudarte ahora.",
        "{SUBJ} {V} hacerlo mañana.",
        "{SUBJ} {V} venir hoy.",
        "{SUBJ} {V} hablar un poco.",
    ],
    "decir": [
        "{SUBJ} {V} la verdad.",
        "{SUBJ} {V} eso otra vez.",
        "{SUBJ} {V} que sí.",
        "{SUBJ} {V} que no.",
    ],
    "ver": [
        "{SUBJ} {V} la tele.",
        "{SUBJ} {V} un video.",
        "{SUBJ} {V} a mis amigos hoy.",
        "{SUBJ} {V} el menú.",
    ],
    "dar": [
        "{SUBJ} {V} un consejo.",
        "{SUBJ} {V} una mano.",
        "{SUBJ} {V} una respuesta.",
        "{SUBJ} {V} un regalo.",
    ],
    "saber": [
        "{SUBJ} {V} la respuesta.",
        "{SUBJ} {V} qué hacer.",
        "{SUBJ} {V} mucho de eso.",
        "{SUBJ} {V} si es verdad.",
    ],
}

# English meanings aligned by template index.
# We will conjugate English to match the Spanish subject + tense.
EN_BASE = {
    "ser": [
        "be from here",
        "be very punctual",
        "be a student",
        "be the boss today",
    ],
    "estar": [
        "be at home",
        "be tired today",
        "be ready",
        "be in a meeting",
    ],
    "tener": [
        "have time right now",
        "have a question",
        "be hungry",
        "have to leave",
    ],
    "hacer": [
        "work out",
        "make dinner",
        "take a break",
        "make a plan",
    ],
    "ir": [
        "go to work",
        "go home",
        "go to the gym",
        "go to the supermarket",
    ],
    "poder": [
        "be able to help you now",
        "be able to do it tomorrow",
        "be able to come today",
        "be able to talk a bit",
    ],
    "decir": [
        "tell the truth",
        "say that again",
        "say yes",
        "say no",
    ],
    "ver": [
        "watch TV",
        "watch a video",
        "see my friends today",
        "look at the menu",
    ],
    "dar": [
        "give some advice",
        "lend a hand",
        "give an answer",
        "give a gift",
    ],
    "saber": [
        "know the answer",
        "know what to do",
        "know a lot about that",
        "know if it is true",
    ],
}

# --- English irregulars (only what we use in EN_BASE) ---
IRREG_3S = {
    "have": "has",
    "go": "goes",
    "do": "does",
    "say": "says",
}

IRREG_PAST = {
    "go": "went",
    "give": "gave",
    "know": "knew",
    "say": "said",
    "tell": "told",
    "see": "saw",
    "make": "made",
    "take": "took",
    "leave": "left",
    "lend": "lent",
    "have": "had",
}

IRREG_PP = {
    "go": "gone",
    "give": "given",
    "know": "known",
    "say": "said",
    "tell": "told",
    "see": "seen",
    "make": "made",
    "take": "taken",
    "leave": "left",
    "lend": "lent",
    "have": "had",
}

@dataclass
class FallbackItem:
    verb: str
    tense: str
    level: str
    spanish: str
    english: str
    notes: str | None = None

def pick_subject(level: str) -> tuple[str, str]:
    # Bias beginners toward yo/tú/él/ella
    if level in ("A1", "A2"):
        options = [SUBJECTS[0], SUBJECTS[1], SUBJECTS[2], SUBJECTS[3]]
    else:
        options = SUBJECTS
    return random.choice(options)

def en_pronoun(subj: str) -> str:
    return {
        "yo": "I",
        "tú": "You",
        "él": "He",
        "ella": "She",
        "nosotros": "We",
        "ellos": "They",
    }[subj]

def en_have_form(subj: str) -> str:
    return "has" if subj in ("él", "ella") else "have"

def en_be_present(subj: str) -> str:
    if subj == "yo":
        return "am"
    if subj in ("él", "ella"):
        return "is"
    return "are"

def en_simple_present(subj: str, verb_base: str) -> str:
    if subj in ("él", "ella"):
        if verb_base in IRREG_3S:
            return IRREG_3S[verb_base]

        # vowel + y -> add s (play->plays, say->says)
        if verb_base.endswith("y") and len(verb_base) > 1:
            if verb_base[-2] in "aeiou":
                return verb_base + "s"
            return verb_base[:-1] + "ies"

        if verb_base.endswith(("s", "sh", "ch", "x", "z", "o")):
            return verb_base + "es"

        return verb_base + "s"
    return verb_base

def en_past(verb_base: str) -> str:
    if verb_base in IRREG_PAST:
        return IRREG_PAST[verb_base]
    if verb_base.endswith("e"):
        return verb_base + "d"
    if verb_base.endswith("y") and len(verb_base) > 1 and verb_base[-2] not in "aeiou":
        return verb_base[:-1] + "ied"
    return verb_base + "ed"

def en_pp(verb_base: str) -> str:
    if verb_base in IRREG_PP:
        return IRREG_PP[verb_base]
    return en_past(verb_base)

def _cleanup_en(s: str) -> str:
    s = s.replace("  ", " ").strip()
    if not s.endswith("."):
        s += "."
    return s

def en_sentence(subj: str, tense: str, meaning: str) -> str:
    pron = en_pronoun(subj)

    # meaning: "be X"
    if meaning.startswith("be "):
        rest = meaning[3:]
        if tense == "present":
            return _cleanup_en(f"{pron} {en_be_present(subj)} {rest}")
        if tense == "preterite":
            was_were = "was" if subj in ("yo", "él", "ella") else "were"
            return _cleanup_en(f"{pron} {was_were} {rest}")
        if tense == "imperfect":
            was_were = "was" if subj in ("yo", "él", "ella") else "were"
            return _cleanup_en(f"{pron} {was_were} {rest}")
        if tense == "future":
            return _cleanup_en(f"{pron} will be {rest}")
        if tense == "present_perfect":
            return _cleanup_en(f"{pron} {en_have_form(subj)} been {rest}")
        if tense == "near_future":
            return _cleanup_en(f"{pron} {en_be_present(subj)} going to be {rest}")

    # meaning: "verb rest"
    parts = meaning.split(" ", 1)
    verb_base = parts[0]
    rest = parts[1] if len(parts) > 1 else ""

    if tense == "present":
        v = en_simple_present(subj, verb_base)
        return _cleanup_en(f"{pron} {v} {rest}")
    if tense == "preterite":
        return _cleanup_en(f"{pron} {en_past(verb_base)} {rest}")
    if tense == "imperfect":
        return _cleanup_en(f"{pron} used to {verb_base} {rest}")
    if tense == "future":
        return _cleanup_en(f"{pron} will {verb_base} {rest}")
    if tense == "present_perfect":
        return _cleanup_en(f"{pron} {en_have_form(subj)} {en_pp(verb_base)} {rest}")
    if tense == "near_future":
        return _cleanup_en(f"{pron} {en_be_present(subj)} going to {verb_base} {rest}")

    return _cleanup_en(f"{pron} {meaning}")

def generate_one(level: str, allowed_tenses: list[str]) -> FallbackItem:
    verb = random.choice(list(CONJ.keys()))
    tense = random.choice([t for t in allowed_tenses if t in CONJ[verb]] or ["present"])
    subj, person = pick_subject(level)

    v = CONJ[verb][tense][person]

    idx = random.randrange(len(TEMPLATES[verb]))
    sp = TEMPLATES[verb][idx].format(SUBJ=subj.capitalize(), V=v)

    meaning = EN_BASE[verb][idx]
    en = en_sentence(subj, tense, meaning)

    return FallbackItem(
        verb=verb,
        tense=tense,
        level=level,
        spanish=sp,
        english=en,
        notes=None,
    )
