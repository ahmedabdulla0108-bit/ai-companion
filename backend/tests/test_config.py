from app.config import Settings

def test_settings_reads_env(monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "a")
    monkeypatch.setenv("ELEVENLABS_API_KEY", "b")
    monkeypatch.setenv("APP_BEARER_TOKEN", "t")
    s = Settings()
    assert s.anthropic_api_key == "a"
    assert s.elevenlabs_api_key == "b"
    assert s.app_bearer_token == "t"
    assert s.default_model == "claude-opus-4-8"
