from functools import lru_cache
from app.config import get_settings
from app.personas.registry import load_core_character, load_personas
from app.store.conversation import ConversationStore
from app.memory.store import FakeMemoryStore, Mem0MemoryStore
from app.providers.llm import FakeLlmClient, ClaudeLlmClient
from app.providers.tts import FakeTtsClient, ElevenLabsTtsClient
from app.chat_service import ChatService

@lru_cache
def get_chat_service() -> ChatService:
    s = get_settings()
    core = load_core_character(s.personas_dir)
    personas = load_personas(s.personas_dir)
    store = ConversationStore(s.conversation_db_path)
    llm = ClaudeLlmClient(s.anthropic_api_key) if s.anthropic_api_key else FakeLlmClient("(no ANTHROPIC_API_KEY set)")
    tts = ElevenLabsTtsClient(s.elevenlabs_api_key) if s.elevenlabs_api_key else FakeTtsClient(None)
    try:
        memory = Mem0MemoryStore()
    except Exception:  # noqa: BLE001 - mem0 optional/unconfigured
        memory = FakeMemoryStore()
    return ChatService(core, personas, store, memory, llm, tts)
