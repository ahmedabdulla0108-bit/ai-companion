import logging
from typing import Protocol

import httpx

logger = logging.getLogger(__name__)


class TtsClient(Protocol):
    def synthesize(self, text: str, voice_id: str) -> bytes | None: ...


class FakeTtsClient:
    def __init__(self, audio: bytes | None = b"AUDIO"):
        self._audio = audio
        self.last_call: dict | None = None

    def synthesize(self, text: str, voice_id: str) -> bytes | None:
        self.last_call = {"text": text, "voice_id": voice_id}
        return self._audio


class ElevenLabsTtsClient:
    def __init__(self, api_key: str, timeout: float = 30.0):
        self._api_key = api_key
        self._timeout = timeout

    def synthesize(self, text: str, voice_id: str) -> bytes | None:
        url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
        try:
            resp = httpx.post(
                url,
                headers={"xi-api-key": self._api_key, "accept": "audio/mpeg"},
                json={"text": text, "model_id": "eleven_turbo_v2_5"},
                timeout=self._timeout,
            )
            if resp.status_code == 200:
                return resp.content
            logger.error("ElevenLabs TTS failed: %s %s", resp.status_code, resp.text[:200])
            return None
        except Exception:  # noqa: BLE001 - graceful degradation
            logger.exception("ElevenLabs TTS error")
            return None
