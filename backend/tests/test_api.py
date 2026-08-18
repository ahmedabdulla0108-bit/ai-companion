# backend/tests/test_api.py
import base64
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.config import get_settings, Settings
from app.deps import get_chat_service
from app.personas.registry import Persona
from app.store.conversation import ConversationStore
from app.memory.store import FakeMemoryStore
from app.providers.llm import FakeLlmClient, LlmError
from app.providers.tts import FakeTtsClient
from app.chat_service import ChatService

@pytest.fixture
def client(tmp_path):
    def _settings():
        return Settings(anthropic_api_key="x", elevenlabs_api_key="x",
                        app_bearer_token="secret")
    persona = Persona("sage", "Sage", "calm", "You are Sage.", "v1",
                      "claude-opus-4-8", 1024, "Hi there")
    svc = ChatService(
        core="CORE", personas={"sage": persona},
        store=ConversationStore(str(tmp_path / "c.db")),
        memory=FakeMemoryStore(), llm=FakeLlmClient("Hello!"),
        tts=FakeTtsClient(b"MP3"),
    )
    app.dependency_overrides[get_settings] = _settings
    app.dependency_overrides[get_chat_service] = lambda: svc
    yield TestClient(app)
    app.dependency_overrides.clear()

AUTH = {"Authorization": "Bearer secret"}

def test_personas_requires_auth(client):
    assert client.get("/personas").status_code == 401

def test_personas_lists(client):
    resp = client.get("/personas", headers=AUTH)
    assert resp.status_code == 200
    assert resp.json()[0]["id"] == "sage"
    assert resp.json()[0]["greeting"] == "Hi there"

def test_chat_happy_path(client):
    resp = client.post("/chat", headers=AUTH, json={
        "userId": "u1", "personaId": "sage", "text": "hi"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["replyText"] == "Hello!"
    assert base64.b64decode(body["audio"]) == b"MP3"
    assert body["conversationId"]

def test_chat_unknown_persona_404(client):
    resp = client.post("/chat", headers=AUTH, json={
        "userId": "u1", "personaId": "ghost", "text": "hi"})
    assert resp.status_code == 404


class _RaisingLlm:
    def complete(self, system, messages, model, max_tokens):
        raise LlmError("provider down")


def test_chat_llm_error_returns_502(tmp_path):
    def _settings():
        return Settings(anthropic_api_key="x", elevenlabs_api_key="x",
                        app_bearer_token="secret")
    persona = Persona("sage", "Sage", "calm", "You are Sage.", "v1",
                      "claude-opus-4-8", 1024, "Hi there")
    svc = ChatService(
        core="CORE", personas={"sage": persona},
        store=ConversationStore(str(tmp_path / "c.db")),
        memory=FakeMemoryStore(), llm=_RaisingLlm(), tts=FakeTtsClient(b"MP3"),
    )
    app.dependency_overrides[get_settings] = _settings
    app.dependency_overrides[get_chat_service] = lambda: svc
    try:
        resp = TestClient(app).post("/chat", headers=AUTH, json={
            "userId": "u1", "personaId": "sage", "text": "hi"})
        assert resp.status_code == 502
    finally:
        app.dependency_overrides.clear()
