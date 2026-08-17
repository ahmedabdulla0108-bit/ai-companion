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

@lru_cache
def get_settings() -> Settings:
    return Settings()
