from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    anthropic_api_key: str = ""
    elevenlabs_api_key: str = ""
    app_bearer_token: str = ""
    conversation_db_path: str = "conversations.db"
    personas_dir: str = "personas"
    default_model: str = "claude-opus-4-8"

    # LLM provider selection. "claude" = Anthropic SDK direct (default).
    # "openai_compat" = any OpenAI-compatible gateway (e.g. OmniRoute) at
    # openai_base_url with openai_api_key; openai_model overrides the persona
    # model when set.
    llm_provider: str = "claude"
    openai_base_url: str = ""       # e.g. http://localhost:20128/api/v1
    openai_api_key: str = ""        # OmniRoute virtual key
    openai_model: str = ""          # model OmniRoute routes on (overrides persona.model)

    # STT (speech-to-text) provider. "whisper" (default) = server-side
    # transcription via an OpenAI-audio compatible endpoint (e.g. Groq Whisper);
    # the app is audio-first, so this matches the app out of the box. Blank
    # whisper_* fields fall back to the openai_* (LLM gateway) values, so the
    # one Groq key set for the LLM covers transcription too. "device" is legacy
    # on-device recognition (the app no longer sends text).
    stt_provider: str = "whisper"
    whisper_base_url: str = ""      # falls back to openai_base_url
    whisper_api_key: str = ""       # falls back to openai_api_key
    whisper_model: str = "whisper-large-v3-turbo"

    # TTS provider selection. "kokoro" (default) = local/free OpenAI-audio
    # server (e.g. Kokoro-FastAPI); the bundled personas ship real Kokoro
    # voices, so this works out of the box. "elevenlabs" is opt-in and requires
    # setting a real per-persona ElevenLabs voice_id.
    tts_provider: str = "kokoro"
    kokoro_base_url: str = ""       # e.g. http://localhost:8880/v1 (local) or a hosted URL
    kokoro_api_key: str = ""        # blank for local Kokoro-FastAPI; set for hosted
    kokoro_voice: str = "af_heart"  # fallback Kokoro voice when a persona has none

@lru_cache
def get_settings() -> Settings:
    return Settings()
