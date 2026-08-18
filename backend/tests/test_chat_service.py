import base64
from app.personas.registry import Persona
from app.store.conversation import ConversationStore
from app.memory.store import FakeMemoryStore
from app.providers.llm import FakeLlmClient
from app.providers.tts import FakeTtsClient
from app.chat_service import ChatService

def _service(tmp_path, audio=b"MP3"):
    persona = Persona("sage", "Sage", "calm", "You are Sage.", "voice-1",
                      "claude-opus-4-8", 1024, "Hi")
    return ChatService(
        core="CORE",
        personas={"sage": persona},
        store=ConversationStore(str(tmp_path / "c.db")),
        memory=FakeMemoryStore(),
        llm=FakeLlmClient(reply="Nice to meet you."),
        tts=FakeTtsClient(audio=audio),
    )

def test_handle_happy_path(tmp_path):
    svc = _service(tmp_path)
    res = svc.handle("u1", "sage", "hello", None)
    assert res.reply_text == "Nice to meet you."
    assert base64.b64decode(res.audio_b64) == b"MP3"
    assert res.conversation_id  # generated

def test_system_prompt_includes_core_and_persona(tmp_path):
    svc = _service(tmp_path)
    svc.handle("u1", "sage", "hello", None)
    sys = svc.llm.last_call["system"]
    assert sys.startswith("CORE")
    assert "You are Sage." in sys

def test_history_is_passed_on_second_turn(tmp_path):
    svc = _service(tmp_path)
    r1 = svc.handle("u1", "sage", "first", None)
    svc.handle("u1", "sage", "second", r1.conversation_id)
    msgs = svc.llm.last_call["messages"]
    # first user, first assistant, second user
    assert msgs[0]["content"] == "first"
    assert msgs[-1]["content"] == "second"

def test_tts_failure_returns_null_audio(tmp_path):
    svc = _service(tmp_path, audio=None)
    res = svc.handle("u1", "sage", "hello", None)
    assert res.audio_b64 is None

def test_unknown_persona_raises(tmp_path):
    svc = _service(tmp_path)
    try:
        svc.handle("u1", "ghost", "hi", None)
        assert False, "expected KeyError"
    except KeyError:
        pass
