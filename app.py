import base64
import time
import streamlit as st
from streamlit_autorefresh import st_autorefresh

from src.config import Settings
from src.generation.template_fallback import TemplateFallbackGenerator
from src.tts.edge_tts import synthesize_mp3
from src.models import GeneratedItem

st.set_page_config(page_title="Spanish Sentences (ES → EN + Voice)", layout="centered")

settings = Settings()
fallback = TemplateFallbackGenerator(settings)

st.session_state.setdefault("seen_count", 0)
st.title(f"Phrases Learned: {st.session_state.seen_count}")

# ----------------------------
# UI helpers
# ----------------------------
def big_text(text: str, size_em: float = 1.35):
    st.markdown(
        f"<div style='font-size:{size_em}em; line-height:1.35'>{text}</div>",
        unsafe_allow_html=True,
    )

def audio_player_bytes(mp3_bytes: bytes):
    """Manual audio player (no autoplay)."""
    b64 = base64.b64encode(mp3_bytes).decode("utf-8")
    st.markdown(
        f"""
        <audio controls>
            <source src="data:audio/mp3;base64,{b64}" type="audio/mpeg">
        </audio>
        """,
        unsafe_allow_html=True,
    )

@st.cache_data(show_spinner=False)
def tts_cached(text: str, voice: str) -> bytes:
    """Cache TTS results to speed up repeat plays."""
    return synthesize_mp3(text, voice=voice)

# ✅ ADDED: a more prominent "pill" showing verb/tense/level
def meta_pill(item: GeneratedItem):
    st.markdown(
        f"""
        <div style="padding:10px 12px;border-radius:14px;background:rgba(0,0,0,0.06);display:inline-block;">
          <b>Verb:</b> {item.verb} &nbsp; • &nbsp; <b>Tense:</b> {item.tense} &nbsp; • &nbsp; <b>Level:</b> {item.level}
        </div>
        """,
        unsafe_allow_html=True,
    )

# ✅ UPDATED: generation now respects an optional focus verb list
def generate_item(settings: Settings, focus_verbs: list[str]) -> GeneratedItem:
    """
    If focus_verbs is non-empty, we keep generating until we get a sentence whose
    item.verb is in the focus list (up to N tries). If focus_verbs is empty,
    we generate normally (all verbs).
    """
    if not focus_verbs:
        return fallback.generate_one(settings=settings)

    # Try a handful of times to hit a focused verb (prevents infinite loops)
    for _ in range(30):
        item = fallback.generate_one(settings=settings)
        if item.verb and item.verb.strip().lower() in focus_verbs:
            return item

    # If we didn't hit one, fall back to whatever we got last
    return fallback.generate_one(settings=settings)

# ----------------------------
# Session state
# ----------------------------
st.session_state.setdefault("item", None)
st.session_state.setdefault("revealed", False)

# autoplay state machine (text only)
st.session_state.setdefault("auto_phase", "idle")  # idle | spanish | english
st.session_state.setdefault("phase_started_at", time.time())
st.session_state.setdefault("autoplay_prev", False)

# prefetch buffer (TEXT ONLY)
st.session_state.setdefault("next_ready", False)
st.session_state.setdefault("next_item", None)

# motivation / feedback
st.session_state.setdefault("seen_count", 0)

# ✅ ADDED: store focus state
st.session_state.setdefault("focus_raw", "")
st.session_state.setdefault("focus_verbs_prev", None)

def clear_prefetch():
    st.session_state.next_ready = False
    st.session_state.next_item = None

# ✅ UPDATED: prefetch now respects focus verbs
def prefetch_next(settings: Settings, focus_verbs: list[str]):
    """Prefetch the next sentence (fast)."""
    if st.session_state.next_ready:
        return
    st.session_state.next_item = generate_item(settings=settings, focus_verbs=focus_verbs)
    st.session_state.next_ready = True

# ✅ UPDATED: advance now respects focus verbs
def advance_to_next(settings: Settings, focus_verbs: list[str]):
    """
    Swap in prefetched next if ready, else generate synchronously.
    We keep revealed=False so English is never shown while the sentence swaps.
    """
    st.session_state.revealed = False

    if st.session_state.next_ready and st.session_state.next_item is not None:
        st.session_state.item = st.session_state.next_item
        clear_prefetch()
    else:
        st.session_state.item = generate_item(settings=settings, focus_verbs=focus_verbs)

    st.session_state.auto_phase = "spanish"
    st.session_state.phase_started_at = time.time()
    st.session_state.seen_count += 1

# ----------------------------
# Sidebar
# ----------------------------
with st.sidebar:
    st.header("Settings")
    st.info("AI generation is disabled for now (fallback mode).")

    level = st.selectbox(
        "Level",
        ["A1", "A2", "B1", "B2", "C1", "C2"],
        index=["A1", "A2", "B1", "B2", "C1", "C2"].index(
            settings.app_level if settings.app_level in ["A1", "A2", "B1", "B2", "C1", "C2"] else "A2"
        ),
    )

    tense_options = [
        ("present", "Present"),
        ("preterite", "Preterite"),
        ("imperfect", "Imperfect"),
        ("future", "Future"),
        ("present_perfect", "Present perfect"),
        ("near_future", "Near future (ir a + infinitive)"),
    ]

    default_internal = settings.app_tenses
    default_labels = [label for (key, label) in tense_options if key in default_internal] or ["Present", "Preterite"]

    chosen_labels = st.multiselect(
        "Tenses",
        [label for (_, label) in tense_options],
        default=default_labels,
    )
    chosen_internal = [key for (key, label) in tense_options if label in chosen_labels]

    include_questions = st.toggle("Include questions sometimes", value=True)
    include_negations = st.toggle("Include negations sometimes", value=True)

    # ✅ ADDED: Verb focus controls
    st.divider()
    st.subheader("Verb focus")

    focus_raw = st.text_area(
        "Focus only these verbs (comma or newline separated). Leave blank to use all.",
        value=st.session_state.get("focus_raw", ""),
        height=90,
        placeholder="comer\nhablar\ntener",
    )
    st.session_state["focus_raw"] = focus_raw

    focus_verbs = sorted({v.strip().lower() for v in focus_raw.replace(",", "\n").splitlines() if v.strip()})

    if focus_verbs:
        st.caption(f"🎯 Focusing on: {', '.join(focus_verbs)}")
    else:
        st.caption("🌎 No focus verbs set — using all verbs.")

    st.divider()
    st.subheader("Hands-free mode")
    autoplay = st.toggle("Auto-advance (no audio)", value=False)
    spanish_seconds = st.slider("Seconds (Spanish → English)", 1, 12, 5)
    english_seconds = st.slider("Seconds (English → next)", 1, 12, 5)

# ✅ ADDED: If focus list changes, clear prefetched next item so it never uses old verb set
prev_focus = st.session_state.get("focus_verbs_prev")
if prev_focus != focus_verbs:
    st.session_state["focus_verbs_prev"] = focus_verbs
    clear_prefetch()
    # optional: uncomment if you want it to restart immediately when focus changes
    # st.session_state.item = None
    # st.session_state.revealed = False
    # st.session_state.auto_phase = "idle"

# apply settings
settings = settings.model_copy(update={
    "app_level": level,
    "include_questions": include_questions,
    "include_negations": include_negations,
})
settings.app_tenses_raw = ",".join(chosen_internal)

# ----------------------------
# Controls (bigger tap targets)
# ----------------------------
col1, col2 = st.columns(2)

with col1:
    if st.button("➕ New sentence", use_container_width=True):
        st.session_state.item = generate_item(settings=settings, focus_verbs=focus_verbs)
        st.session_state.revealed = False
        st.session_state.auto_phase = "spanish"
        st.session_state.phase_started_at = time.time()
        st.session_state.seen_count += 1
        clear_prefetch()

with col2:
    if st.button("👀 Reveal English", use_container_width=True):
        if st.session_state.item is not None:
            st.session_state.revealed = True
            st.session_state.auto_phase = "english"
            st.session_state.phase_started_at = time.time()

# ----------------------------
# Autoplay tick (text-only; fast + reliable)
# ----------------------------
if autoplay:
    st_autorefresh(interval=500, key="autorefresh_autoplay")

# If autoplay was just turned on, start immediately
if autoplay and not st.session_state.autoplay_prev:
    if st.session_state.item is None:
        st.session_state.item = generate_item(settings=settings, focus_verbs=focus_verbs)
        st.session_state.seen_count += 1
    st.session_state.revealed = False
    st.session_state.auto_phase = "spanish"
    st.session_state.phase_started_at = time.time()
    clear_prefetch()

st.session_state.autoplay_prev = autoplay

# Autoplay engine
item: GeneratedItem | None = st.session_state.item

if autoplay and item is not None and st.session_state.auto_phase != "idle":
    elapsed = time.time() - st.session_state.phase_started_at

    if st.session_state.auto_phase == "spanish" and elapsed >= spanish_seconds:
        st.session_state.revealed = True
        st.session_state.auto_phase = "english"
        st.session_state.phase_started_at = time.time()
        # while on English, prefetch next (text-only)
        prefetch_next(settings, focus_verbs)

    elif st.session_state.auto_phase == "english" and elapsed >= english_seconds:
        advance_to_next(settings, focus_verbs)
        item = st.session_state.item

st.divider()

# ----------------------------
# UI rendering (conditional)
# ----------------------------
if item is None:
    st.info("Click **New sentence** or turn on **Auto-advance** to start.")
else:
    # Show ONLY Spanish when not revealed
    if not st.session_state.revealed:
        st.subheader("Spanish")
        big_text(item.spanish, size_em=1.5)

        # ✅ UPDATED: show big verb/tense/level pill
        meta_pill(item)

        mp3_es = tts_cached(item.spanish, settings.app_tts_voice_es)
        audio_player_bytes(mp3_es)

    # Show ONLY English when revealed
    else:
        st.subheader("Spanish")
        big_text(item.spanish, size_em=1.5)

        # ✅ UPDATED: show big verb/tense/level pill
        meta_pill(item)

        st.subheader("English")
        big_text(item.english, size_em=1.35)

        mp3_en = tts_cached(item.english, settings.app_tts_voice_en)
        audio_player_bytes(mp3_en)
