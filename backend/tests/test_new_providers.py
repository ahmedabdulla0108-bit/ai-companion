import pytest

import app.providers.llm as llmmod
import app.providers.tts as ttsmod
from app.providers.llm import OpenAiCompatLlmClient, LlmError
from app.providers.tts import KokoroTtsClient


class _Resp:
    def __init__(self, status_code=200, json_data=None, content=b"", text=""):
        self.status_code = status_code
        self._json = json_data
        self.content = content
        self.text = text

    def raise_for_status(self):
        if self.status_code >= 400:
            raise RuntimeError(f"HTTP {self.status_code}")

    def json(self):
        return self._json


def test_openai_compat_complete_parses_content_and_overrides_model(monkeypatch):
    captured = {}

    def fake_post(url, headers=None, json=None, timeout=None):
        captured.update(url=url, headers=headers, json=json)
        return _Resp(json_data={"choices": [{"message": {"content": "hi there"}}]})

    monkeypatch.setattr(llmmod.httpx, "post", fake_post)
    c = OpenAiCompatLlmClient("http://x/api/v1", "vk-1", model_override="omni-model")
    out = c.complete(system="CORE", messages=[{"role": "user", "content": "hello"}],
                     model="claude-opus-4-8", max_tokens=100)
    assert out == "hi there"
    assert captured["url"] == "http://x/api/v1/chat/completions"
    assert captured["json"]["model"] == "omni-model"  # override wins over persona model
    assert captured["json"]["messages"][0] == {"role": "system", "content": "CORE"}
    assert captured["headers"]["Authorization"] == "Bearer vk-1"


def test_openai_compat_wraps_errors_as_llmerror(monkeypatch):
    def boom(*a, **k):
        raise RuntimeError("connection refused")

    monkeypatch.setattr(llmmod.httpx, "post", boom)
    c = OpenAiCompatLlmClient("http://x/api/v1", "vk-1")
    with pytest.raises(LlmError):
        c.complete(system="s", messages=[], model="m", max_tokens=10)


def test_kokoro_returns_bytes_and_falls_back_to_default_voice(monkeypatch):
    captured = {}

    def fake_post(url, headers=None, json=None, timeout=None):
        captured.update(url=url, json=json)
        return _Resp(status_code=200, content=b"MP3")

    monkeypatch.setattr(ttsmod.httpx, "post", fake_post)
    c = KokoroTtsClient("http://localhost:8880/v1", default_voice="af_heart")
    audio = c.synthesize("hello", "REPLACE_WITH_ELEVENLABS_VOICE_ID")
    assert audio == b"MP3"
    assert captured["url"] == "http://localhost:8880/v1/audio/speech"
    assert captured["json"]["voice"] == "af_heart"  # placeholder id → default voice
    assert captured["json"]["response_format"] == "mp3"


def test_kokoro_uses_explicit_voice_and_degrades_on_error(monkeypatch):
    def fake_post(url, headers=None, json=None, timeout=None):
        assert json["voice"] == "am_adam"
        return _Resp(status_code=500, text="boom")

    monkeypatch.setattr(ttsmod.httpx, "post", fake_post)
    c = KokoroTtsClient("http://localhost:8880/v1")
    assert c.synthesize("hi", "am_adam") is None
