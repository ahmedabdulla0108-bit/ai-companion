# Voice Companion

A cross-platform (Android + iOS) voice companion: talk out loud and it talks back
in a switchable **persona** that shares one intelligent, balanced **Core Character
Layer**, and it **remembers you** across sessions. Version 1 is tap-to-talk.

## Repository map

- **Design spec:** [`docs/superpowers/specs/2026-08-17-voice-companion-design.md`](docs/superpowers/specs/2026-08-17-voice-companion-design.md)
- **Implementation plan:** [`docs/superpowers/plans/2026-08-17-voice-companion.md`](docs/superpowers/plans/2026-08-17-voice-companion.md)
- **Backend (FastAPI "brain"):** [`backend/`](backend/) — holds the API keys and does the thinking. See [`backend/README.md`](backend/README.md).
- **App (Flutter "face"):** [`app/`](app/) — captures voice, shows/plays the reply. See [`app/README.md`](app/README.md).

## How it works

```
Flutter app  ──HTTPS (bearer token)──▶  FastAPI backend
 on-device STT                           Core Character Layer + persona
 hold-to-talk        {userId,personaId,  Claude (reply) → mem0 (memory)
 audio playback  ◀── text} / {replyText, → ElevenLabs (voice)
 device-voice fallback   audio, convId}   SQLite (recent turns)
```

One turn: hold the button → on-device speech-to-text → `POST /chat` → the backend
assembles `core character + persona + memories + recent history`, asks Claude, saves
memory, synthesizes the voice with ElevenLabs, and returns text + base64 audio → the
app shows the text and plays the voice (or speaks it with the device voice if TTS is
unavailable).

## v1 scope

Tap-to-talk, on-device speech-to-text, Claude brain (`claude-opus-4-8`, no adaptive
thinking for low latency), ElevenLabs voice, mem0 memory shared across personas,
bearer-token auth, graceful degradation when any cloud service is down. The backend
runs locally during personal testing.

**Planned for v2:** background wake word, response/sentence streaming for lower
latency, adaptive "go deep" thinking, and cloud deployment with per-user auth before
any public release.

## Quick start

1. Backend: `cd backend && pip install -e ".[dev]"`, copy `.env.example` → `.env`,
   `uvicorn app.main:app --host 0.0.0.0 --port 8000`. Boots with blank keys (fakes).
2. App: `cd app && flutter run` on an Android phone, then point Settings at your
   PC's `http://<lan-ip>:8000` with the same bearer token.

Full details in the backend and app READMEs.
