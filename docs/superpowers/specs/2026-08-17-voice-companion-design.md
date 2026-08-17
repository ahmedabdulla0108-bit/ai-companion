# Voice Companion — Design Spec

**Date:** 2026-08-17
**Status:** Approved design (pre-implementation)
**Author:** brainstormed with Claude Code

## 1. Summary

A cross-platform (Android + iOS) **voice companion**: you talk to it out loud,
it talks back in a distinct character voice, it has switchable **personas**, and
it **remembers you** across sessions. Every persona shares a **Core Character
Layer** — a common "soul" that is intelligent, balanced, emotionally aware, and a
genuine thinking/creative partner. Version 1 is **tap-to-talk**; a background
**wake word** is deferred to v2.

The system is split into two pieces:

- **Flutter app** ("the face") — captures voice, shows the conversation, plays
  the reply. Holds no API keys and no AI logic.
- **FastAPI backend** ("the brain") — holds all API keys and does the thinking:
  Claude for conversation, mem0 for memory, ElevenLabs for the character voice.

During personal testing the backend runs **locally on the developer's PC** (zero
hosting cost). When the app is published, the same backend is deployed.

## 2. Goals / Non-Goals

### Goals (v1)
- Hold-to-talk voice loop: speak → hear the persona reply, on a real Android phone.
- Multiple switchable personas defined in config, each with its own personality
  and voice.
- A shared **Core Character Layer** giving every persona these qualities:
  highly intelligent (reasons carefully, goes deep), low-bias / balanced
  (multiple perspectives, anti-sycophancy, honest but kind), situationally aware
  (reads and matches emotional register), tactfully mood-lightening (levity when
  things get heavy, without dismissing), reflective (reflects your patterns back,
  asks good questions), a **thinking partner** (helps you think deeper, pushes
  back, sharpens ideas), and **creativity-releasing** (offers unexpected angles,
  brainstorms).
- Long-term memory of the user, **shared across all personas** (every character
  knows the same facts about the user).
- Cross-platform Flutter codebase (test on Android first; iOS buildable later).
- API keys never ship inside the app.
- Graceful degradation when any cloud service is unavailable.
- Snappy enough to feel like a conversation.

### Non-Goals (deferred to v2+)
- Background / always-on wake word (v1 is tap-to-talk).
- Response streaming / sentence-level TTS for lower latency.
- Extended (adaptive) thinking — omitted in v1 to keep voice latency low.
- A dedicated "reflect with me" introspection feature (introspection is a
  behavioral trait of the Core Character Layer in v1, not a separate mode).
- Cloud hosting / public app-store release (design must not preclude it, but it
  is not part of v1).
- Per-persona private memory (v1 memory is shared-only).

## 3. Decisions (locked)

| Decision | Choice | Rationale |
|---|---|---|
| Runtime | Phone-first, cross-platform | User target; test Android first, publish both later |
| Framework | **Flutter** | User preference; strong audio/speech plugins |
| Architecture | Thin app + brain backend ("Approach A") | Keys stay server-side; memory centralized; iterate personas without app rebuilds |
| Voice stack | **Hybrid**: on-device STT + cloud LLM + cloud TTS | Fast/free STT locally; best brain and voice in the cloud |
| STT | On-device speech recognition (`speech_to_text`) | Low latency, free, no audio leaves device unnecessarily |
| LLM | Anthropic **Claude**, default `claude-opus-4-8`, per-persona configurable | Highest intelligence; matches the "highly intelligent" goal |
| Thinking | **None in v1** (adaptive thinking omitted) | Opus 4.8 runs without thinking when `thinking` is omitted → low voice latency |
| TTS | **ElevenLabs** (per-persona voice), with on-device fallback | Character-grade voices; degrade gracefully |
| Character model | **Core Character Layer** (shared "soul") + per-persona flavor | One consistent, high-quality character under many skins |
| Memory | **mem0**, scoped **per user, shared across personas** | Companion "friends who all know you" feel |
| Trigger | **Tap-to-talk** (hold to talk) in v1 | Dodges mobile background-mic limits; wake word is v2 |
| Backend deployment | Local during testing, deployed on publish | No hosting cost until needed |

## 4. Architecture

```
┌─────────────────────────────┐        HTTPS (bearer token)        ┌──────────────────────────────┐
│         Flutter app          │  ───────────────────────────────▶ │        FastAPI backend         │
│  (Android / iOS)             │                                    │  ("the brain")                 │
│                              │  POST /chat {userId,personaId,text}│                                │
│  • Talk screen (hold-to-talk)│                                    │  • Core Character Layer        │
│  • On-device STT             │  ◀─────────────────────────────── │  • Persona registry (YAML)     │
│  • Persona picker            │   {replyText, audio(base64),       │  • mem0 memory (retrieve/write) │
│  • Audio playback            │    conversationId}                 │  • SQLite recent-turn store    │
│  • Settings (backend URL)    │                                    │  • Claude client               │
│  • flutter_tts fallback voice│                                    │  • ElevenLabs client           │
└─────────────────────────────┘                                    └──────────────────────────────┘
```

## 5. Data flow — one conversation turn

1. User presses and holds the talk button.
2. On-device STT transcribes speech → text (the "local" half of hybrid).
3. App `POST /chat` with `{userId, personaId, text, conversationId?}` + bearer token.
4. Backend retrieves relevant memories for `userId` (mem0) + recent turns for
   `conversationId` (SQLite).
5. Backend assembles the Claude prompt:
   `system = Core Character Layer + persona.system_prompt + rendered memories`,
   then recent history, then the new user message. No `thinking` parameter is
   sent (fast path); `max_tokens` is small (spoken replies are short).
6. Claude returns the reply text (in character).
7. Backend writes the exchange to mem0 (extracts/updates facts about the user)
   and appends the turn to SQLite. The memory write is fire-and-forget so it does
   not block the response.
8. Backend calls ElevenLabs with `persona.voice_id` → MP3 audio.
9. Backend responds `{replyText, audio(base64), conversationId}`.
10. App displays the text and plays the audio.

## 6. Component design

### 6.1 Flutter app

**Screens**
- **Talk screen:** large press-and-hold talk button, live transcript, current
  persona name/avatar, "speaking" indicator, conversation transcript list.
- **Persona picker:** list of characters from `GET /personas`; tap to switch.
- **Settings:** backend base URL + bearer token, user id/display name.

**Key packages**
- `speech_to_text` — on-device speech recognition.
- `just_audio` — play returned MP3.
- `flutter_tts` — fallback voice if ElevenLabs audio is absent.
- `dio` — HTTP client.
- `flutter_riverpod` — state management.
- `shared_preferences` — persist backend URL, token, active persona, userId.

**State**
- App holds no secrets beyond the backend bearer token (user-provided).
- Active persona and userId persisted locally; conversation history is
  authoritative on the server, optionally cached locally for display.

### 6.2 FastAPI backend

**Endpoints**
- `GET /health` → `{status: "ok"}`.
- `GET /personas` → `[{id, name, description, greeting}]`.
- `POST /chat` → body `{userId, personaId, text, conversationId?}` →
  `{replyText, audio (base64 mp3, nullable), conversationId}`.
- Auth: static bearer token via `Authorization: Bearer <token>` middleware.
  Sufficient for personal use; replace with per-user auth before public release.

**Core Character Layer**
- A single system-prompt fragment, stored as `personas/_core_character.md`,
  prepended to *every* persona's own `system_prompt`. It encodes the shared
  qualities from §2 Goals (intelligence, low bias, situational awareness,
  mood-lightening, reflectiveness, thinking-partner, creativity). Editing this
  one file changes the "soul" of every persona at once.

**Persona registry**
- One YAML file per persona in `personas/`:
  ```yaml
  id: sage
  name: Sage
  description: A calm, thoughtful companion.
  system_prompt: |
    You are Sage, a warm, unhurried companion who ...   # persona FLAVOR only;
                                                         # the Core Character Layer
                                                         # is prepended automatically
  voice_id: <elevenlabs-voice-id>
  model: claude-opus-4-8
  max_tokens: 1024
  greeting: "Hey, it's good to hear you."
  ```
- Loaded at startup; a persona is added by dropping in a new file. The effective
  system prompt is `core_character + "\n\n" + persona.system_prompt`.

**Memory (mem0)**
- Retrieve: `mem0.search(query=user_text, user_id=userId)` → top-k memories,
  rendered into the system prompt.
- Write: after the reply, `mem0.add([{role:user...},{role:assistant...}], user_id=userId)`.
- Scope: keyed by `userId` only → **shared across personas** by design.

**Conversation store (SQLite)**
- Table of turns keyed by `conversationId` with role, text, timestamp, personaId.
- Provides a short recent-history window for in-session coherence; mem0 handles
  long-term facts. Recent-window size is a small constant (e.g. last N turns).

**Provider clients**
- `LlmClient` (Anthropic Claude) and `TtsClient` (ElevenLabs) behind thin
  interfaces so either can be mocked in tests or swapped later.
- Secrets (`ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY`, `APP_BEARER_TOKEN`) via
  `.env` / environment; never committed.

## 7. Error handling / graceful degradation

| Failure | Behavior |
|---|---|
| No speech detected (STT) | App shows "didn't catch that — try again"; no backend call. |
| Backend unreachable | App shows "can't reach [persona] right now"; offer retry. |
| Claude error / rate-limit | Backend returns a clear error; app shows a friendly retry. |
| mem0 retrieve fails | Proceed without memories (log it); the turn still works. |
| mem0 write fails | Log and continue; response is unaffected (write is non-blocking). |
| ElevenLabs fails | Backend returns `audio: null`; app **speaks the text via `flutter_tts`** so the companion still talks. |
| Request timeout | Bounded timeouts on all provider calls; app surfaces a retry. |

## 8. Testing strategy (TDD)

**Backend**
- Core Character Layer + persona loading: valid/invalid/missing files; effective
  prompt is core + flavor.
- Prompt assembly: core + persona + memories + history composed correctly.
- Memory: retrieve-before / write-after with mem0 mocked.
- `/chat` endpoint via FastAPI `TestClient` with Claude + ElevenLabs clients
  mocked (happy path + each degradation branch).
- Auth middleware: rejects missing/incorrect bearer token.

**App**
- Widget tests for talk-screen states (idle, listening, thinking, speaking,
  error) against a mocked backend client.
- Persona picker switches active persona.
- ElevenLabs-absent path triggers `flutter_tts` fallback.
- Then real device runs on the developer's Android phone.

## 9. Security & privacy

- API keys live only in the backend `.env`; the app never holds them.
- App↔backend protected by a bearer token; upgrade to per-user auth before any
  public release.
- Memory contains personal facts — stored server-side; deployment must use HTTPS
  and access controls. (Detailed hardening is a pre-publish task, not v1.)

## 10. Repository layout (proposed)

```
ai-companion/
├─ backend/
│  ├─ app/                 # FastAPI application
│  │  ├─ main.py
│  │  ├─ routes/           # /health, /personas, /chat
│  │  ├─ personas/         # loader + registry + core-character loader
│  │  ├─ memory/           # mem0 wrapper
│  │  ├─ providers/        # llm (Claude), tts (ElevenLabs) clients
│  │  ├─ store/            # SQLite conversation store
│  │  └─ config.py
│  ├─ personas/            # _core_character.md + *.yaml persona files
│  ├─ tests/
│  └─ pyproject.toml / requirements.txt
├─ app/                    # Flutter application
│  ├─ lib/
│  │  ├─ screens/          # talk, persona picker, settings
│  │  ├─ services/         # backend client, stt, playback, tts fallback
│  │  ├─ state/            # riverpod providers
│  │  └─ main.dart
│  └─ test/
├─ docs/superpowers/specs/
└─ README.md
```

## 11. Open items for the implementation plan

- Exact Claude model id: default `claude-opus-4-8`; per-persona `model` allows
  `claude-sonnet-5` (cheaper/faster) or Opus 4.8 **fast mode** as latency levers.
- ElevenLabs voice ids for the initial personas (needs an ElevenLabs account).
- Whether to return audio inline (base64) or via a short-lived URL — base64 is
  simplest for v1.
- Initial persona set (start with 1–2 well-defined characters on top of the
  shared Core Character Layer).
