from functools import lru_cache
from app.config import Settings, get_settings
from app.personas.registry import load_core_character, load_personas
from app.store.conversation import ConversationStore
from app.memory.store import FakeMemoryStore, Mem0MemoryStore
from app.providers.llm import FakeLlmClient, ClaudeLlmClient, OpenAiCompatLlmClient
from app.providers.tts import FakeTtsClient, ElevenLabsTtsClient, KokoroTtsClient
from app.providers.transcribe import WhisperTranscribeClient
from app.chat_service import ChatService


def _build_llm(s: Settings):
    if s.llm_provider == "openai_compat" and s.openai_base_url:
        return OpenAiCompatLlmClient(s.openai_base_url, s.openai_api_key, model_override=s.openai_model)
    if s.anthropic_api_key:
        return ClaudeLlmClient(s.anthropic_api_key)
    return FakeLlmClient(
        "I'm in test mode without a language model connected yet, but I can hear "
        "you clearly and speak right back. Try the people icon to switch personas "
        "and you'll hear a different voice."
    )


def _build_tts(s: Settings):
    if s.tts_provider == "kokoro" and s.kokoro_base_url:
        return KokoroTtsClient(s.kokoro_base_url, default_voice=s.kokoro_voice, api_key=s.kokoro_api_key)
    if s.elevenlabs_api_key:
        return ElevenLabsTtsClient(s.elevenlabs_api_key)
    return FakeTtsClient(None)


def _build_transcribe(s: Settings):
    if s.stt_provider == "whisper":
        base = s.whisper_base_url or s.openai_base_url
        key = s.whisper_api_key or s.openai_api_key
        if base:
            return WhisperTranscribeClient(base, key, model=s.whisper_model)
    return None


@lru_cache
def get_chat_service() -> ChatService:
    s = get_settings()
    core = load_core_character(s.personas_dir)
    personas = load_personas(s.personas_dir)
    store = ConversationStore(s.conversation_db_path)
    llm = _build_llm(s)
    tts = _build_tts(s)
    transcribe = _build_transcribe(s)
    try:
        memory = Mem0MemoryStore()
    except Exception:  # noqa: BLE001 - mem0 optional/unconfigured
        memory = FakeMemoryStore()
    return ChatService(core, personas, store, memory, llm, tts, transcribe=transcribe)
