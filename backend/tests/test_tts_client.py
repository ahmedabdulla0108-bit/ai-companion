from app.providers.tts import FakeTtsClient


def test_fake_tts_returns_bytes():
    tts = FakeTtsClient(audio=b"MP3DATA")
    out = tts.synthesize("hello", "voice-1")
    assert out == b"MP3DATA"
    assert tts.last_call == {"text": "hello", "voice_id": "voice-1"}


def test_fake_tts_can_fail():
    tts = FakeTtsClient(audio=None)
    assert tts.synthesize("x", "v") is None
