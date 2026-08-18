import logging
from typing import Protocol

import httpx

logger = logging.getLogger(__name__)


class TranscribeError(RuntimeError):
    """Raised when the speech-to-text provider call fails."""


class TranscribeClient(Protocol):
    def transcribe(self, audio: bytes, filename: str = "audio.m4a") -> str: ...


class FakeTranscribeClient:
    def __init__(self, text: str = "(fake transcript)"):
        self._text = text
        self.last_call: dict | None = None

    def transcribe(self, audio: bytes, filename: str = "audio.m4a") -> str:
        self.last_call = {"bytes": len(audio), "filename": filename}
        return self._text


class WhisperTranscribeClient:
    """Speech-to-text via an OpenAI-compatible audio/transcriptions endpoint
    (e.g. Groq Whisper `whisper-large-v3-turbo`). Sends the audio as multipart
    form data and returns the recognized text."""

    def __init__(self, base_url: str, api_key: str,
                 model: str = "whisper-large-v3-turbo", timeout: float = 60.0):
        self._base_url = base_url.rstrip("/")
        self._api_key = api_key
        self._model = model
        self._timeout = timeout

    def transcribe(self, audio: bytes, filename: str = "audio.m4a") -> str:
        try:
            resp = httpx.post(
                f"{self._base_url}/audio/transcriptions",
                headers={"Authorization": f"Bearer {self._api_key}"},
                files={"file": (filename, audio, "application/octet-stream")},
                data={"model": self._model},
                timeout=self._timeout,
            )
            resp.raise_for_status()
            return (resp.json().get("text") or "").strip()
        except Exception as e:  # noqa: BLE001 - surface as provider error
            raise TranscribeError(f"transcription request failed: {e}") from e
