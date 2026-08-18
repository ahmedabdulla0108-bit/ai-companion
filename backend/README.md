# Voice Companion — Backend

The "brain" of the voice companion: a FastAPI service that holds the API keys and
does the thinking (Claude for conversation, mem0 for memory, ElevenLabs for the
character voice). The Flutter app talks to it over HTTP with a bearer token.

## Setup

1. `cd backend`
2. Create and activate a virtualenv:
   - Windows (Git Bash): `python -m venv .venv && . .venv/Scripts/activate`
   - macOS/Linux: `python -m venv .venv && . .venv/bin/activate`
3. Install the app (plus test tooling):
   `pip install -e ".[dev]"`
   - Runtime only: `pip install -e .`
   - With real long-term memory (mem0): `pip install -e ".[dev,memory]"`
4. `cp .env.example .env` and fill in real values:
   - `ANTHROPIC_API_KEY` — your Anthropic key.
   - `ELEVENLABS_API_KEY` — your ElevenLabs key.
   - `APP_BEARER_TOKEN` — a long random string; the app must send `Authorization: Bearer <this>`.
   - `CONVERSATION_DB_PATH` — optional; defaults to `conversations.db` in the working dir.
5. Put real ElevenLabs `voice_id`s in `personas/*.yaml` (they ship with a
   `REPLACE_WITH_ELEVENLABS_VOICE_ID` placeholder).

### Graceful degradation (no keys needed to boot)

The app boots even with blank keys so you can develop offline:
- No `ANTHROPIC_API_KEY` → a fake LLM replies with a placeholder string.
- No `ELEVENLABS_API_KEY` → `audio` comes back `null` and the app speaks the text
  with the on-device fallback voice.
- mem0 not installed/configured → a no-op memory store; every turn still works.

So `/health`, `/personas`, and `/chat` all respond without any credentials — you
just get fake replies and no audio until you add real keys.

### mem0 (optional long-term memory)

Real cross-session memory needs the `memory` extra (`pip install -e ".[memory]"`)
plus a mem0-configured extraction LLM + embedder (see the mem0 docs). Memory is
keyed by `userId` only, so it is shared across every persona. Memory failures
never break a turn — they are logged/swallowed and the reply still returns.

## Run

```
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Bind `0.0.0.0` (not `127.0.0.1`) so a phone on the same Wi-Fi can reach it at
`http://<your-pc-ip>:8000`. Find your PC's LAN IP with `ipconfig` (Windows) or
`ipconfig getifaddr en0` (macOS). Point the Flutter app's backend URL at that
address and use the same `APP_BEARER_TOKEN`.

## Smoke test

With the server running (replace `secret` with your `APP_BEARER_TOKEN`):

```bash
export APP_BEARER_TOKEN=secret

# open — no auth
curl -s localhost:8000/health
# → {"status":"ok"}

# auth required
curl -s localhost:8000/personas -H "Authorization: Bearer $APP_BEARER_TOKEN"
# → [{"id":"sage",...},{"id":"nova",...}]

# a full turn
curl -s localhost:8000/chat \
  -H "Authorization: Bearer $APP_BEARER_TOKEN" \
  -H "content-type: application/json" \
  -d '{"userId":"u1","personaId":"sage","text":"hi there"}'
# → {"replyText":"...", "audio":<base64 mp3 or null>, "conversationId":"..."}
```

A request without the bearer header returns `401`; an unknown `personaId`
returns `404`.

## Tests

```
pytest -v
```

Runs entirely against fakes (no network, no keys). All provider clients sit
behind thin interfaces so Claude and ElevenLabs are swapped for fakes in tests.
