# Voice Companion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cross-platform voice companion — a Flutter app that captures speech, sends it to a FastAPI "brain" backend (Claude + mem0 memory + ElevenLabs voice), and speaks the reply in a switchable persona that shares one intelligent, balanced Core Character Layer.

**Architecture:** Thin Flutter client + FastAPI backend ("Approach A"). The app does on-device speech-to-text and audio playback only; the backend holds all API keys and runs the LLM, memory, and text-to-speech. v1 is tap-to-talk; memory is shared across personas; backend runs locally during personal testing.

**Tech Stack:** Backend — Python 3.11+, FastAPI, pydantic-settings, Anthropic SDK (`anthropic`), `httpx`, `mem0ai`, SQLite (stdlib `sqlite3`), `pytest`. App — Flutter (Dart), `speech_to_text`, `just_audio`, `flutter_tts`, `dio`, `flutter_riverpod`, `shared_preferences`.

**Spec:** `docs/superpowers/specs/2026-08-17-voice-companion-design.md`

## Global Constraints

- **Claude model:** default `claude-opus-4-8`; each persona may override via its `model` field. Never send a `thinking` parameter in v1 (keeps voice latency low — Opus 4.8 runs without thinking when omitted). Use exactly the string `claude-opus-4-8`; do not append a date suffix.
- **max_tokens:** per persona, default `1024` (spoken replies are short). Non-streaming `client.messages.create`.
- **Secrets** live only in `backend/.env` (git-ignored): `ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY`, `APP_BEARER_TOKEN`, optional `MEM0_*`. Never commit real keys; commit `.env.example` with placeholder values.
- **Auth:** every `/chat` and `/personas` request must carry `Authorization: Bearer <APP_BEARER_TOKEN>`; `/health` is open.
- **Audio:** ElevenLabs returns MP3; the backend returns it base64-encoded in `audio` (nullable). When TTS fails, `audio` is `null` and the app falls back to the device voice.
- **Memory scope:** mem0 keyed by `user_id` only (shared across personas). Memory failures must never break a turn.
- **Persona prompt:** effective system prompt is always `core_character + "\n\n" + persona.system_prompt + "\n\n" + rendered_memories`.
- **Backend base path for tests:** run `pytest` from `backend/`.

---

### Task 1: Backend scaffold + health endpoint

**Files:**
- Create: `backend/pyproject.toml`
- Create: `backend/.env.example`
- Create: `backend/.gitignore`
- Create: `backend/app/__init__.py`
- Create: `backend/app/main.py`
- Test: `backend/tests/test_health.py`

**Interfaces:**
- Consumes: nothing.
- Produces: `app.main:app` (FastAPI instance) with `GET /health` → `{"status": "ok"}`.

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_health.py
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_ok():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}
```

- [ ] **Step 2: Create project files**

```toml
# backend/pyproject.toml
[project]
name = "voice-companion-backend"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
  "fastapi>=0.110",
  "uvicorn[standard]>=0.29",
  "pydantic-settings>=2.2",
  "anthropic>=0.40",
  "httpx>=0.27",
  "pyyaml>=6.0",
  "mem0ai>=0.1.0",
]

[project.optional-dependencies]
dev = ["pytest>=8.0"]

[tool.pytest.ini_options]
pythonpath = ["."]
testpaths = ["tests"]
```

```gitignore
# backend/.gitignore
.env
__pycache__/
*.pyc
*.db
.venv/
```

```
# backend/.env.example
ANTHROPIC_API_KEY=sk-ant-xxx
ELEVENLABS_API_KEY=xxx
APP_BEARER_TOKEN=change-me-to-a-long-random-string
CONVERSATION_DB_PATH=conversations.db
```

- [ ] **Step 3: Implement the app**

```python
# backend/app/__init__.py
```

```python
# backend/app/main.py
from fastapi import FastAPI

app = FastAPI(title="Voice Companion Backend")

@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
```

- [ ] **Step 4: Install and run the test**

Run: `cd backend && python -m venv .venv && . .venv/Scripts/activate && pip install -e ".[dev]" && pytest tests/test_health.py -v`
(On Git Bash for Windows use `. .venv/Scripts/activate`; on macOS/Linux `. .venv/bin/activate`.)
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/
git commit -m "feat(backend): scaffold FastAPI app with health endpoint"
```

---

### Task 2: Settings / config loader

**Files:**
- Create: `backend/app/config.py`
- Test: `backend/tests/test_config.py`

**Interfaces:**
- Consumes: environment variables / `.env`.
- Produces: `app.config:Settings` (pydantic-settings) with fields `anthropic_api_key: str`, `elevenlabs_api_key: str`, `app_bearer_token: str`, `conversation_db_path: str = "conversations.db"`, `personas_dir: str = "personas"`, `default_model: str = "claude-opus-4-8"`; and `app.config:get_settings() -> Settings` (cached).

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_config.py
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
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `pytest tests/test_config.py -v`
Expected: FAIL (`ModuleNotFoundError: app.config`).

- [ ] **Step 3: Implement**

```python
# backend/app/config.py
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
```

- [ ] **Step 4: Run the test**

Run: `pytest tests/test_config.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/config.py backend/tests/test_config.py
git commit -m "feat(backend): settings loader"
```

---

### Task 3: Core Character Layer + persona registry

**Files:**
- Create: `backend/app/personas/__init__.py`
- Create: `backend/app/personas/registry.py`
- Create: `backend/personas/_core_character.md`
- Create: `backend/personas/sage.yaml`
- Create: `backend/personas/nova.yaml`
- Test: `backend/tests/test_personas.py`

**Interfaces:**
- Consumes: files under `personas_dir`.
- Produces:
  - `Persona` dataclass: `id: str`, `name: str`, `description: str`, `system_prompt: str`, `voice_id: str`, `model: str`, `max_tokens: int`, `greeting: str`.
  - `load_core_character(personas_dir: str) -> str` (reads `_core_character.md`).
  - `load_personas(personas_dir: str) -> dict[str, Persona]` (all `*.yaml`).
  - `effective_system_prompt(core: str, persona: Persona, memories: list[str]) -> str`.

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_personas.py
from pathlib import Path
from app.personas.registry import (
    load_core_character, load_personas, effective_system_prompt,
)

def _write(tmp_path: Path):
    (tmp_path / "_core_character.md").write_text("CORE SOUL", encoding="utf-8")
    (tmp_path / "sage.yaml").write_text(
        "id: sage\nname: Sage\ndescription: calm\n"
        "system_prompt: You are Sage.\nvoice_id: v1\n"
        "model: claude-opus-4-8\nmax_tokens: 1024\ngreeting: Hi\n",
        encoding="utf-8",
    )

def test_loads_core_and_persona(tmp_path):
    _write(tmp_path)
    core = load_core_character(str(tmp_path))
    personas = load_personas(str(tmp_path))
    assert core == "CORE SOUL"
    assert personas["sage"].name == "Sage"
    assert personas["sage"].voice_id == "v1"

def test_effective_prompt_prepends_core_and_memories(tmp_path):
    _write(tmp_path)
    core = load_core_character(str(tmp_path))
    p = load_personas(str(tmp_path))["sage"]
    prompt = effective_system_prompt(core, p, ["likes tea"])
    assert prompt.startswith("CORE SOUL")
    assert "You are Sage." in prompt
    assert "likes tea" in prompt
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `pytest tests/test_personas.py -v`
Expected: FAIL (module missing).

- [ ] **Step 3: Implement the registry**

```python
# backend/app/personas/__init__.py
```

```python
# backend/app/personas/registry.py
from dataclasses import dataclass
from pathlib import Path
import yaml

@dataclass
class Persona:
    id: str
    name: str
    description: str
    system_prompt: str
    voice_id: str
    model: str
    max_tokens: int
    greeting: str

def load_core_character(personas_dir: str) -> str:
    path = Path(personas_dir) / "_core_character.md"
    return path.read_text(encoding="utf-8").strip()

def load_personas(personas_dir: str) -> dict[str, Persona]:
    personas: dict[str, Persona] = {}
    for path in sorted(Path(personas_dir).glob("*.yaml")):
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        persona = Persona(
            id=data["id"],
            name=data["name"],
            description=data.get("description", ""),
            system_prompt=data["system_prompt"],
            voice_id=data["voice_id"],
            model=data.get("model", "claude-opus-4-8"),
            max_tokens=int(data.get("max_tokens", 1024)),
            greeting=data.get("greeting", ""),
        )
        personas[persona.id] = persona
    return personas

def effective_system_prompt(core: str, persona: Persona, memories: list[str]) -> str:
    parts = [core, persona.system_prompt]
    if memories:
        rendered = "\n".join(f"- {m}" for m in memories)
        parts.append(f"What you remember about the person you're talking to:\n{rendered}")
    return "\n\n".join(parts)
```

- [ ] **Step 4: Create the real persona content**

```markdown
<!-- backend/personas/_core_character.md -->
You are a voice companion the user talks to out loud. Whatever character you are
playing, you always embody these qualities:

- Highly intelligent. Reason carefully and go deep; never dumb things down.
- Balanced and low-bias. Weigh multiple perspectives. Do not flatter or simply
  agree — tell the truth kindly rather than telling the user what they want to hear.
- Situationally aware. Read the emotional register of what the user says and match
  it — serious when they are serious, never tone-deaf.
- Able to lighten the mood. When things get heavy, know when and how to add levity
  without dismissing what the user feels.
- Reflective. Because you remember the user across conversations, notice their
  patterns, reflect them back gently, and ask good questions.
- A thinking partner. Help the user think deeper: push back, sharpen their ideas,
  offer angles they haven't considered.
- Creativity-releasing. Encourage exploration and brainstorming; offer surprising,
  generative ideas rather than safe, obvious ones.

You are speaking aloud, so keep replies conversational and reasonably short unless
the user clearly wants depth. Do not narrate actions or use stage directions.
```

```yaml
# backend/personas/sage.yaml
id: sage
name: Sage
description: A calm, grounded companion who helps you think things through.
system_prompt: |
  You are Sage: warm, unhurried, and grounded. You favor clarity and gentle,
  probing questions over quick answers. Your voice is steady and reassuring.
voice_id: REPLACE_WITH_ELEVENLABS_VOICE_ID
model: claude-opus-4-8
max_tokens: 1024
greeting: "Hey, good to hear you. What's on your mind?"
```

```yaml
# backend/personas/nova.yaml
id: nova
name: Nova
description: A bright, playful companion who sparks ideas and keeps things light.
system_prompt: |
  You are Nova: energetic, witty, and curious. You love riffing on ideas and
  making people laugh, but you read the room and get real when it matters.
voice_id: REPLACE_WITH_ELEVENLABS_VOICE_ID
model: claude-opus-4-8
max_tokens: 1024
greeting: "Hey you! Okay, what are we getting into today?"
```

- [ ] **Step 5: Run the test**

Run: `pytest tests/test_personas.py -v`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/app/personas backend/personas backend/tests/test_personas.py
git commit -m "feat(backend): core character layer + persona registry"
```

---

### Task 4: SQLite conversation store

**Files:**
- Create: `backend/app/store/__init__.py`
- Create: `backend/app/store/conversation.py`
- Test: `backend/tests/test_conversation_store.py`

**Interfaces:**
- Consumes: a db path (`:memory:` acceptable in tests via a shared connection, but use a temp file path for isolation).
- Produces:
  - `Turn` dataclass: `role: str`, `text: str`, `persona_id: str`, `ts: str`.
  - `ConversationStore(db_path: str)` with `add_turn(conversation_id, role, text, persona_id) -> None` and `recent_turns(conversation_id, limit: int = 10) -> list[Turn]` (oldest-first).

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_conversation_store.py
from app.store.conversation import ConversationStore

def test_add_and_read_recent(tmp_path):
    db = str(tmp_path / "c.db")
    store = ConversationStore(db)
    store.add_turn("c1", "user", "hello", "sage")
    store.add_turn("c1", "assistant", "hi there", "sage")
    store.add_turn("c2", "user", "other convo", "sage")
    turns = store.recent_turns("c1", limit=10)
    assert [t.role for t in turns] == ["user", "assistant"]
    assert turns[0].text == "hello"

def test_recent_turns_limit_and_order(tmp_path):
    store = ConversationStore(str(tmp_path / "c.db"))
    for i in range(5):
        store.add_turn("c1", "user", f"m{i}", "sage")
    turns = store.recent_turns("c1", limit=3)
    assert [t.text for t in turns] == ["m2", "m3", "m4"]  # last 3, oldest-first
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `pytest tests/test_conversation_store.py -v`
Expected: FAIL (module missing).

- [ ] **Step 3: Implement**

```python
# backend/app/store/__init__.py
```

```python
# backend/app/store/conversation.py
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone

@dataclass
class Turn:
    role: str
    text: str
    persona_id: str
    ts: str

class ConversationStore:
    def __init__(self, db_path: str):
        self._db_path = db_path
        with self._connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS turns (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    conversation_id TEXT NOT NULL,
                    role TEXT NOT NULL,
                    text TEXT NOT NULL,
                    persona_id TEXT NOT NULL,
                    ts TEXT NOT NULL
                )
                """
            )

    def _connect(self) -> sqlite3.Connection:
        return sqlite3.connect(self._db_path)

    def add_turn(self, conversation_id: str, role: str, text: str, persona_id: str) -> None:
        ts = datetime.now(timezone.utc).isoformat()
        with self._connect() as conn:
            conn.execute(
                "INSERT INTO turns (conversation_id, role, text, persona_id, ts) "
                "VALUES (?, ?, ?, ?, ?)",
                (conversation_id, role, text, persona_id, ts),
            )

    def recent_turns(self, conversation_id: str, limit: int = 10) -> list[Turn]:
        with self._connect() as conn:
            rows = conn.execute(
                "SELECT role, text, persona_id, ts FROM turns "
                "WHERE conversation_id = ? ORDER BY id DESC LIMIT ?",
                (conversation_id, limit),
            ).fetchall()
        rows.reverse()  # oldest-first
        return [Turn(role=r[0], text=r[1], persona_id=r[2], ts=r[3]) for r in rows]
```

- [ ] **Step 4: Run the test**

Run: `pytest tests/test_conversation_store.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/store backend/tests/test_conversation_store.py
git commit -m "feat(backend): sqlite conversation store"
```

---

### Task 5: Memory store (mem0 wrapper + fake)

**Files:**
- Create: `backend/app/memory/__init__.py`
- Create: `backend/app/memory/store.py`
- Test: `backend/tests/test_memory_store.py`

**Interfaces:**
- Produces:
  - `MemoryStore` Protocol: `search(user_id: str, query: str) -> list[str]`; `add(user_id: str, user_text: str, assistant_text: str) -> None`.
  - `FakeMemoryStore` (in-memory, for tests and offline dev): stores added texts, `search` returns all stored strings for the user.
  - `Mem0MemoryStore` (real): wraps `mem0.Memory`. Both `search` and `add` swallow exceptions and log, returning `[]` / doing nothing on failure (degrade gracefully per spec §7).

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_memory_store.py
from app.memory.store import FakeMemoryStore

def test_fake_memory_roundtrip():
    m = FakeMemoryStore()
    m.add("u1", "I love hiking", "Nice, where do you hike?")
    m.add("u1", "My dog is named Rex", "Rex sounds great")
    results = m.search("u1", "pets")
    assert any("Rex" in r for r in results)

def test_fake_memory_isolated_by_user():
    m = FakeMemoryStore()
    m.add("u1", "secret a", "ok")
    assert m.search("u2", "anything") == []
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `pytest tests/test_memory_store.py -v`
Expected: FAIL.

- [ ] **Step 3: Implement**

```python
# backend/app/memory/__init__.py
```

```python
# backend/app/memory/store.py
import logging
from typing import Protocol

logger = logging.getLogger(__name__)

class MemoryStore(Protocol):
    def search(self, user_id: str, query: str) -> list[str]: ...
    def add(self, user_id: str, user_text: str, assistant_text: str) -> None: ...

class FakeMemoryStore:
    def __init__(self) -> None:
        self._by_user: dict[str, list[str]] = {}

    def search(self, user_id: str, query: str) -> list[str]:
        return list(self._by_user.get(user_id, []))

    def add(self, user_id: str, user_text: str, assistant_text: str) -> None:
        self._by_user.setdefault(user_id, []).append(user_text)

class Mem0MemoryStore:
    """Real mem0-backed store. Requires mem0 to be configured with an
    extraction LLM + embedder (see backend/README). All failures degrade to
    no-op so a turn never breaks (spec §7)."""

    def __init__(self) -> None:
        from mem0 import Memory
        self._mem = Memory()

    def search(self, user_id: str, query: str) -> list[str]:
        try:
            res = self._mem.search(query=query, user_id=user_id)
            items = res.get("results", res) if isinstance(res, dict) else res
            return [i["memory"] for i in items][:5]
        except Exception:  # noqa: BLE001 - graceful degradation
            logger.exception("mem0 search failed")
            return []

    def add(self, user_id: str, user_text: str, assistant_text: str) -> None:
        try:
            self._mem.add(
                [
                    {"role": "user", "content": user_text},
                    {"role": "assistant", "content": assistant_text},
                ],
                user_id=user_id,
            )
        except Exception:  # noqa: BLE001 - graceful degradation
            logger.exception("mem0 add failed")
```

- [ ] **Step 4: Run the test**

Run: `pytest tests/test_memory_store.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/memory backend/tests/test_memory_store.py
git commit -m "feat(backend): memory store interface with mem0 impl and fake"
```

---

### Task 6: LLM client (Claude) + fake

**Files:**
- Create: `backend/app/providers/__init__.py`
- Create: `backend/app/providers/llm.py`
- Test: `backend/tests/test_llm_client.py`

**Interfaces:**
- Produces:
  - `LlmClient` Protocol: `complete(system: str, messages: list[dict], model: str, max_tokens: int) -> str`.
  - `FakeLlmClient(reply: str)`: records the last call args on `self.last_call`; returns `reply`.
  - `ClaudeLlmClient(api_key: str)`: real Anthropic SDK. Builds `client.messages.create(model=model, max_tokens=max_tokens, system=system, messages=messages)` with **no** `thinking` param; extracts the first text block.

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_llm_client.py
from app.providers.llm import FakeLlmClient

def test_fake_llm_records_and_replies():
    llm = FakeLlmClient(reply="hello back")
    out = llm.complete(
        system="SYS",
        messages=[{"role": "user", "content": "hi"}],
        model="claude-opus-4-8",
        max_tokens=1024,
    )
    assert out == "hello back"
    assert llm.last_call["system"] == "SYS"
    assert llm.last_call["model"] == "claude-opus-4-8"
    assert llm.last_call["messages"][-1]["content"] == "hi"
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `pytest tests/test_llm_client.py -v`
Expected: FAIL.

- [ ] **Step 3: Implement**

```python
# backend/app/providers/__init__.py
```

```python
# backend/app/providers/llm.py
from typing import Protocol

class LlmClient(Protocol):
    def complete(self, system: str, messages: list[dict], model: str, max_tokens: int) -> str: ...

class FakeLlmClient:
    def __init__(self, reply: str = "ok"):
        self._reply = reply
        self.last_call: dict | None = None

    def complete(self, system: str, messages: list[dict], model: str, max_tokens: int) -> str:
        self.last_call = {
            "system": system, "messages": messages,
            "model": model, "max_tokens": max_tokens,
        }
        return self._reply

class ClaudeLlmClient:
    def __init__(self, api_key: str):
        import anthropic
        self._client = anthropic.Anthropic(api_key=api_key)

    def complete(self, system: str, messages: list[dict], model: str, max_tokens: int) -> str:
        # No `thinking` param on purpose — keeps voice latency low (Opus 4.8
        # runs without thinking when omitted).
        resp = self._client.messages.create(
            model=model,
            max_tokens=max_tokens,
            system=system,
            messages=messages,
        )
        for block in resp.content:
            if block.type == "text":
                return block.text
        return ""
```

- [ ] **Step 4: Run the test**

Run: `pytest tests/test_llm_client.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/providers/__init__.py backend/app/providers/llm.py backend/tests/test_llm_client.py
git commit -m "feat(backend): Claude LLM client with fake"
```

---

### Task 7: TTS client (ElevenLabs) + fake

**Files:**
- Create: `backend/app/providers/tts.py`
- Test: `backend/tests/test_tts_client.py`

**Interfaces:**
- Produces:
  - `TtsClient` Protocol: `synthesize(text: str, voice_id: str) -> bytes | None` (returns MP3 bytes, or `None` on failure).
  - `FakeTtsClient(audio: bytes | None)`: returns the configured bytes; records `last_call`.
  - `ElevenLabsTtsClient(api_key: str)`: POSTs to `https://api.elevenlabs.io/v1/text-to-speech/{voice_id}` with header `xi-api-key`; returns response bytes on 200, `None` (logged) otherwise or on exception.

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_tts_client.py
from app.providers.tts import FakeTtsClient

def test_fake_tts_returns_bytes():
    tts = FakeTtsClient(audio=b"MP3DATA")
    out = tts.synthesize("hello", "voice-1")
    assert out == b"MP3DATA"
    assert tts.last_call == {"text": "hello", "voice_id": "voice-1"}

def test_fake_tts_can_fail():
    tts = FakeTtsClient(audio=None)
    assert tts.synthesize("x", "v") is None
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `pytest tests/test_tts_client.py -v`
Expected: FAIL.

- [ ] **Step 3: Implement**

```python
# backend/app/providers/tts.py
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
```

- [ ] **Step 4: Run the test**

Run: `pytest tests/test_tts_client.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/providers/tts.py backend/tests/test_tts_client.py
git commit -m "feat(backend): ElevenLabs TTS client with fake"
```

---

### Task 8: ChatService (orchestration)

**Files:**
- Create: `backend/app/chat_service.py`
- Test: `backend/tests/test_chat_service.py`

**Interfaces:**
- Consumes: `load_core_character`/`load_personas`/`effective_system_prompt` (Task 3), `ConversationStore` (Task 4), `MemoryStore` (Task 5), `LlmClient` (Task 6), `TtsClient` (Task 7).
- Produces:
  - `ChatResult` dataclass: `reply_text: str`, `audio_b64: str | None`, `conversation_id: str`.
  - `ChatService(core, personas, store, memory, llm, tts)` with `handle(user_id, persona_id, text, conversation_id: str | None) -> ChatResult`. Raises `KeyError` for unknown persona (route maps to 404 later). Generates a `conversation_id` (uuid4 hex) when none is given. Builds messages from recent turns + new user text; persists both turns; calls memory.add after the reply; base64-encodes audio when present.

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_chat_service.py
import base64
from app.personas.registry import Persona
from app.store.conversation import ConversationStore
from app.memory.store import FakeMemoryStore
from app.providers.llm import FakeLlmClient
from app.providers.tts import FakeTtsClient
from app.chat_service import ChatService

def _service(tmp_path, audio=b"MP3"):
    persona = Persona("sage", "Sage", "calm", "You are Sage.", "voice-1",
                      "claude-opus-4-8", 1024, "Hi")
    return ChatService(
        core="CORE",
        personas={"sage": persona},
        store=ConversationStore(str(tmp_path / "c.db")),
        memory=FakeMemoryStore(),
        llm=FakeLlmClient(reply="Nice to meet you."),
        tts=FakeTtsClient(audio=audio),
    )

def test_handle_happy_path(tmp_path):
    svc = _service(tmp_path)
    res = svc.handle("u1", "sage", "hello", None)
    assert res.reply_text == "Nice to meet you."
    assert base64.b64decode(res.audio_b64) == b"MP3"
    assert res.conversation_id  # generated

def test_system_prompt_includes_core_and_persona(tmp_path):
    svc = _service(tmp_path)
    svc.handle("u1", "sage", "hello", None)
    sys = svc.llm.last_call["system"]
    assert sys.startswith("CORE")
    assert "You are Sage." in sys

def test_history_is_passed_on_second_turn(tmp_path):
    svc = _service(tmp_path)
    r1 = svc.handle("u1", "sage", "first", None)
    svc.handle("u1", "sage", "second", r1.conversation_id)
    msgs = svc.llm.last_call["messages"]
    # first user, first assistant, second user
    assert msgs[0]["content"] == "first"
    assert msgs[-1]["content"] == "second"

def test_tts_failure_returns_null_audio(tmp_path):
    svc = _service(tmp_path, audio=None)
    res = svc.handle("u1", "sage", "hello", None)
    assert res.audio_b64 is None

def test_unknown_persona_raises(tmp_path):
    svc = _service(tmp_path)
    try:
        svc.handle("u1", "ghost", "hi", None)
        assert False, "expected KeyError"
    except KeyError:
        pass
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `pytest tests/test_chat_service.py -v`
Expected: FAIL.

- [ ] **Step 3: Implement**

```python
# backend/app/chat_service.py
import base64
import uuid
from dataclasses import dataclass

from app.personas.registry import Persona, effective_system_prompt
from app.store.conversation import ConversationStore
from app.memory.store import MemoryStore
from app.providers.llm import LlmClient
from app.providers.tts import TtsClient

@dataclass
class ChatResult:
    reply_text: str
    audio_b64: str | None
    conversation_id: str

class ChatService:
    def __init__(self, core: str, personas: dict[str, Persona],
                 store: ConversationStore, memory: MemoryStore,
                 llm: LlmClient, tts: TtsClient):
        self.core = core
        self.personas = personas
        self.store = store
        self.memory = memory
        self.llm = llm
        self.tts = tts

    def handle(self, user_id: str, persona_id: str, text: str,
               conversation_id: str | None) -> ChatResult:
        persona = self.personas[persona_id]  # KeyError -> 404 at route layer
        conversation_id = conversation_id or uuid.uuid4().hex

        memories = self.memory.search(user_id, text)
        system = effective_system_prompt(self.core, persona, memories)

        history = self.store.recent_turns(conversation_id, limit=10)
        messages = [{"role": t.role, "content": t.text} for t in history]
        messages.append({"role": "user", "content": text})

        reply = self.llm.complete(
            system=system, messages=messages,
            model=persona.model, max_tokens=persona.max_tokens,
        )

        self.store.add_turn(conversation_id, "user", text, persona_id)
        self.store.add_turn(conversation_id, "assistant", reply, persona_id)
        self.memory.add(user_id, text, reply)  # non-critical; impls swallow errors

        audio = self.tts.synthesize(reply, persona.voice_id)
        audio_b64 = base64.b64encode(audio).decode("ascii") if audio else None

        return ChatResult(reply_text=reply, audio_b64=audio_b64,
                          conversation_id=conversation_id)
```

- [ ] **Step 4: Run the test**

Run: `pytest tests/test_chat_service.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/chat_service.py backend/tests/test_chat_service.py
git commit -m "feat(backend): ChatService orchestration"
```

---

### Task 9: Auth dependency (bearer token)

**Files:**
- Create: `backend/app/auth.py`
- Test: `backend/tests/test_auth.py`

**Interfaces:**
- Produces: `require_bearer(authorization: str | None) -> None` FastAPI dependency that raises `HTTPException(401)` unless the header equals `Bearer <settings.app_bearer_token>`. Reads the token from `get_settings()`.

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_auth.py
import pytest
from fastapi import HTTPException
from app.auth import verify_token

def test_verify_accepts_correct_token():
    verify_token("Bearer secret", expected="secret")  # no raise

def test_verify_rejects_missing():
    with pytest.raises(HTTPException) as e:
        verify_token(None, expected="secret")
    assert e.value.status_code == 401

def test_verify_rejects_wrong():
    with pytest.raises(HTTPException) as e:
        verify_token("Bearer nope", expected="secret")
    assert e.value.status_code == 401
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `pytest tests/test_auth.py -v`
Expected: FAIL.

- [ ] **Step 3: Implement**

```python
# backend/app/auth.py
from fastapi import Header, HTTPException
from app.config import get_settings

def verify_token(authorization: str | None, expected: str) -> None:
    if not authorization or authorization != f"Bearer {expected}":
        raise HTTPException(status_code=401, detail="Unauthorized")

def require_bearer(authorization: str | None = Header(default=None)) -> None:
    verify_token(authorization, expected=get_settings().app_bearer_token)
```

- [ ] **Step 4: Run the test**

Run: `pytest tests/test_auth.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/auth.py backend/tests/test_auth.py
git commit -m "feat(backend): bearer-token auth dependency"
```

---

### Task 10: Wire routes + app composition (/personas, /chat)

**Files:**
- Create: `backend/app/deps.py`
- Create: `backend/app/routes/__init__.py`
- Create: `backend/app/routes/personas.py`
- Create: `backend/app/routes/chat.py`
- Modify: `backend/app/main.py`
- Test: `backend/tests/test_api.py`

**Interfaces:**
- Consumes: `ChatService` (Task 8), `require_bearer` (Task 9), registry loaders (Task 3).
- Produces:
  - `app.deps:get_chat_service() -> ChatService` — builds the service from settings, choosing real vs fake providers based on whether keys are present (fakes when keys are blank, so the app boots for tests/offline dev). Overridable via `app.dependency_overrides`.
  - `GET /personas` → `[{id, name, description, greeting}]` (auth required).
  - `POST /chat` body `{userId, personaId, text, conversationId?}` → `{replyText, audio, conversationId}` (auth required; unknown persona → 404).

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_api.py
import base64
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.config import get_settings, Settings
from app.deps import get_chat_service
from app.personas.registry import Persona
from app.store.conversation import ConversationStore
from app.memory.store import FakeMemoryStore
from app.providers.llm import FakeLlmClient
from app.providers.tts import FakeTtsClient
from app.chat_service import ChatService

@pytest.fixture
def client(tmp_path):
    def _settings():
        return Settings(anthropic_api_key="x", elevenlabs_api_key="x",
                        app_bearer_token="secret")
    persona = Persona("sage", "Sage", "calm", "You are Sage.", "v1",
                      "claude-opus-4-8", 1024, "Hi there")
    svc = ChatService(
        core="CORE", personas={"sage": persona},
        store=ConversationStore(str(tmp_path / "c.db")),
        memory=FakeMemoryStore(), llm=FakeLlmClient("Hello!"),
        tts=FakeTtsClient(b"MP3"),
    )
    app.dependency_overrides[get_settings] = _settings
    app.dependency_overrides[get_chat_service] = lambda: svc
    yield TestClient(app)
    app.dependency_overrides.clear()

AUTH = {"Authorization": "Bearer secret"}

def test_personas_requires_auth(client):
    assert client.get("/personas").status_code == 401

def test_personas_lists(client):
    resp = client.get("/personas", headers=AUTH)
    assert resp.status_code == 200
    assert resp.json()[0]["id"] == "sage"
    assert resp.json()[0]["greeting"] == "Hi there"

def test_chat_happy_path(client):
    resp = client.post("/chat", headers=AUTH, json={
        "userId": "u1", "personaId": "sage", "text": "hi"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["replyText"] == "Hello!"
    assert base64.b64decode(body["audio"]) == b"MP3"
    assert body["conversationId"]

def test_chat_unknown_persona_404(client):
    resp = client.post("/chat", headers=AUTH, json={
        "userId": "u1", "personaId": "ghost", "text": "hi"})
    assert resp.status_code == 404
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `pytest tests/test_api.py -v`
Expected: FAIL.

- [ ] **Step 3: Implement deps + routes**

```python
# backend/app/deps.py
from functools import lru_cache
from app.config import get_settings
from app.personas.registry import load_core_character, load_personas
from app.store.conversation import ConversationStore
from app.memory.store import FakeMemoryStore, Mem0MemoryStore
from app.providers.llm import FakeLlmClient, ClaudeLlmClient
from app.providers.tts import FakeTtsClient, ElevenLabsTtsClient
from app.chat_service import ChatService

@lru_cache
def get_chat_service() -> ChatService:
    s = get_settings()
    core = load_core_character(s.personas_dir)
    personas = load_personas(s.personas_dir)
    store = ConversationStore(s.conversation_db_path)
    llm = ClaudeLlmClient(s.anthropic_api_key) if s.anthropic_api_key else FakeLlmClient("(no ANTHROPIC_API_KEY set)")
    tts = ElevenLabsTtsClient(s.elevenlabs_api_key) if s.elevenlabs_api_key else FakeTtsClient(None)
    try:
        memory = Mem0MemoryStore()
    except Exception:  # noqa: BLE001 - mem0 optional/unconfigured
        memory = FakeMemoryStore()
    return ChatService(core, personas, store, memory, llm, tts)
```

```python
# backend/app/routes/__init__.py
```

```python
# backend/app/routes/personas.py
from fastapi import APIRouter, Depends
from app.auth import require_bearer
from app.deps import get_chat_service
from app.chat_service import ChatService

router = APIRouter()

@router.get("/personas", dependencies=[Depends(require_bearer)])
def list_personas(svc: ChatService = Depends(get_chat_service)) -> list[dict]:
    return [
        {"id": p.id, "name": p.name, "description": p.description, "greeting": p.greeting}
        for p in svc.personas.values()
    ]
```

```python
# backend/app/routes/chat.py
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from app.auth import require_bearer
from app.deps import get_chat_service
from app.chat_service import ChatService

router = APIRouter()

class ChatRequest(BaseModel):
    userId: str
    personaId: str
    text: str
    conversationId: str | None = None

class ChatResponse(BaseModel):
    replyText: str
    audio: str | None
    conversationId: str

@router.post("/chat", response_model=ChatResponse, dependencies=[Depends(require_bearer)])
def chat(req: ChatRequest, svc: ChatService = Depends(get_chat_service)) -> ChatResponse:
    try:
        result = svc.handle(req.userId, req.personaId, req.text, req.conversationId)
    except KeyError:
        raise HTTPException(status_code=404, detail=f"Unknown persona: {req.personaId}")
    return ChatResponse(
        replyText=result.reply_text,
        audio=result.audio_b64,
        conversationId=result.conversation_id,
    )
```

- [ ] **Step 4: Register routers in main.py**

```python
# backend/app/main.py
from fastapi import FastAPI
from app.routes import personas, chat

app = FastAPI(title="Voice Companion Backend")

@app.get("/health")
def health() -> dict:
    return {"status": "ok"}

app.include_router(personas.router)
app.include_router(chat.router)
```

- [ ] **Step 5: Run the tests**

Run: `pytest tests/test_api.py -v`
Expected: PASS.

- [ ] **Step 6: Full suite + commit**

Run: `pytest -v`
Expected: all PASS.

```bash
git add backend/app backend/tests/test_api.py
git commit -m "feat(backend): wire /personas and /chat routes"
```

---

### Task 11: Backend README + local run

**Files:**
- Create: `backend/README.md`
- Test: manual smoke test (documented below).

**Interfaces:**
- Consumes: everything above.
- Produces: documented local-run command and a curl smoke test.

- [ ] **Step 1: Write the README**

```markdown
# Voice Companion — Backend

## Setup
1. `cd backend`
2. `python -m venv .venv && . .venv/Scripts/activate` (Windows Git Bash) or `. .venv/bin/activate`
3. `pip install -e ".[dev]"`
4. `cp .env.example .env` and fill in real keys:
   - `ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY`, a long random `APP_BEARER_TOKEN`.
5. Put real ElevenLabs `voice_id`s in `personas/*.yaml`.
6. mem0 (optional): configure an extraction LLM + embedder per mem0 docs. If
   unconfigured the app falls back to a no-op memory store and still works.

## Run
`uvicorn app.main:app --host 0.0.0.0 --port 8000`
(`0.0.0.0` so your phone on the same Wi-Fi can reach it at `http://<pc-ip>:8000`.)

## Smoke test
```
curl -s localhost:8000/health
curl -s localhost:8000/personas -H "Authorization: Bearer $APP_BEARER_TOKEN"
curl -s localhost:8000/chat -H "Authorization: Bearer $APP_BEARER_TOKEN" \
  -H "content-type: application/json" \
  -d '{"userId":"u1","personaId":"sage","text":"hi there"}'
```
```

- [ ] **Step 2: Run the smoke test**

Start the server and run the three curls. Expected: health ok; personas list; chat returns `replyText` (+ `audio` if ElevenLabs keys/voice are set).

- [ ] **Step 3: Commit**

```bash
git add backend/README.md
git commit -m "docs(backend): local run + smoke test"
```

---

### Task 12: Flutter app scaffold + dependencies + settings model

**Files:**
- Create: `app/` via `flutter create` (then trim)
- Modify: `app/pubspec.yaml`
- Create: `app/lib/models/app_settings.dart`
- Create: `app/lib/state/settings_provider.dart`
- Test: `app/test/app_settings_test.dart`

**Interfaces:**
- Produces:
  - `AppSettings` (immutable): `backendUrl: String`, `bearerToken: String`, `userId: String`; `copyWith(...)`; `toJson()/fromJson()`.
  - `settingsProvider` (Riverpod `StateNotifierProvider`) that loads/saves via `shared_preferences`.

- [ ] **Step 1: Create the Flutter project**

Run: `flutter create --org com.beast app` then set `app/pubspec.yaml` dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  speech_to_text: ^6.6.0
  just_audio: ^0.9.36
  flutter_tts: ^3.8.5
  dio: ^5.4.0
  shared_preferences: ^2.2.2
dev_dependencies:
  flutter_test:
    sdk: flutter
```

Run: `cd app && flutter pub get`.

- [ ] **Step 2: Write the failing test**

```dart
// app/test/app_settings_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/app_settings.dart';

void main() {
  test('copyWith and json roundtrip', () {
    const s = AppSettings(backendUrl: 'http://x', bearerToken: 't', userId: 'u');
    final s2 = s.copyWith(userId: 'u2');
    expect(s2.userId, 'u2');
    expect(s2.backendUrl, 'http://x');
    final restored = AppSettings.fromJson(s2.toJson());
    expect(restored.userId, 'u2');
  });
}
```

- [ ] **Step 3: Run it to confirm it fails**

Run: `flutter test test/app_settings_test.dart`
Expected: FAIL (missing file).

- [ ] **Step 4: Implement AppSettings**

```dart
// app/lib/models/app_settings.dart
class AppSettings {
  final String backendUrl;
  final String bearerToken;
  final String userId;

  const AppSettings({
    required this.backendUrl,
    required this.bearerToken,
    required this.userId,
  });

  AppSettings copyWith({String? backendUrl, String? bearerToken, String? userId}) =>
      AppSettings(
        backendUrl: backendUrl ?? this.backendUrl,
        bearerToken: bearerToken ?? this.bearerToken,
        userId: userId ?? this.userId,
      );

  Map<String, dynamic> toJson() =>
      {'backendUrl': backendUrl, 'bearerToken': bearerToken, 'userId': userId};

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        backendUrl: j['backendUrl'] as String? ?? '',
        bearerToken: j['bearerToken'] as String? ?? '',
        userId: j['userId'] as String? ?? 'me',
      );

  static const empty = AppSettings(backendUrl: '', bearerToken: '', userId: 'me');
}
```

- [ ] **Step 5: Implement the settings provider**

```dart
// app/lib/state/settings_provider.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/models/app_settings.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings.empty) {
    _load();
  }

  static const _key = 'app_settings';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      state = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
  }

  Future<void> save(AppSettings s) async {
    state = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toJson()));
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());
```

- [ ] **Step 6: Run the test + commit**

Run: `flutter test test/app_settings_test.dart`
Expected: PASS.

```bash
git add app/
git commit -m "feat(app): flutter scaffold + settings model/provider"
```

---

### Task 13: Backend API client + persona model

**Files:**
- Create: `app/lib/models/persona.dart`
- Create: `app/lib/models/chat_result.dart`
- Create: `app/lib/services/backend_client.dart`
- Test: `app/test/backend_client_test.dart`

**Interfaces:**
- Produces:
  - `Persona`: `id, name, description, greeting` + `fromJson`.
  - `ChatResult`: `replyText: String`, `audioBytes: Uint8List?` (decoded from base64), `conversationId: String` + `fromJson`.
  - `BackendClient` interface: `Future<List<Persona>> listPersonas()`; `Future<ChatResult> chat({required String userId, required String personaId, required String text, String? conversationId})`.
  - `DioBackendClient(Dio dio, {required String baseUrl, required String token})` implementing it (sets `Authorization` header).

- [ ] **Step 1: Write the failing test** (uses Dio's `MockAdapter` via `dio` test utilities — here, inject a fake `BackendClient` to validate parsing, and unit-test `ChatResult.fromJson`).

```dart
// app/test/backend_client_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/chat_result.dart';
import 'package:app/models/persona.dart';

void main() {
  test('ChatResult decodes base64 audio', () {
    final audio = base64Encode([1, 2, 3]);
    final r = ChatResult.fromJson({
      'replyText': 'hi', 'audio': audio, 'conversationId': 'c1',
    });
    expect(r.replyText, 'hi');
    expect(r.conversationId, 'c1');
    expect(r.audioBytes, isNotNull);
    expect(r.audioBytes!.toList(), [1, 2, 3]);
  });

  test('ChatResult tolerates null audio', () {
    final r = ChatResult.fromJson({
      'replyText': 'hi', 'audio': null, 'conversationId': 'c1',
    });
    expect(r.audioBytes, isNull);
  });

  test('Persona parses', () {
    final p = Persona.fromJson({'id': 'sage', 'name': 'Sage', 'description': 'd', 'greeting': 'g'});
    expect(p.name, 'Sage');
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/backend_client_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement models + client**

```dart
// app/lib/models/persona.dart
class Persona {
  final String id, name, description, greeting;
  const Persona({required this.id, required this.name, required this.description, required this.greeting});
  factory Persona.fromJson(Map<String, dynamic> j) => Persona(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        greeting: j['greeting'] as String? ?? '',
      );
}
```

```dart
// app/lib/models/chat_result.dart
import 'dart:convert';
import 'dart:typed_data';

class ChatResult {
  final String replyText;
  final Uint8List? audioBytes;
  final String conversationId;
  const ChatResult({required this.replyText, required this.audioBytes, required this.conversationId});

  factory ChatResult.fromJson(Map<String, dynamic> j) {
    final audio = j['audio'] as String?;
    return ChatResult(
      replyText: j['replyText'] as String,
      audioBytes: audio == null ? null : base64Decode(audio),
      conversationId: j['conversationId'] as String,
    );
  }
}
```

```dart
// app/lib/services/backend_client.dart
import 'package:dio/dio.dart';
import 'package:app/models/persona.dart';
import 'package:app/models/chat_result.dart';

abstract class BackendClient {
  Future<List<Persona>> listPersonas();
  Future<ChatResult> chat({
    required String userId,
    required String personaId,
    required String text,
    String? conversationId,
  });
}

class DioBackendClient implements BackendClient {
  final Dio _dio;
  final String baseUrl;
  final String token;
  DioBackendClient(this._dio, {required this.baseUrl, required this.token});

  Options get _opts => Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<List<Persona>> listPersonas() async {
    final resp = await _dio.get('$baseUrl/personas', options: _opts);
    return (resp.data as List).map((e) => Persona.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<ChatResult> chat({
    required String userId,
    required String personaId,
    required String text,
    String? conversationId,
  }) async {
    final resp = await _dio.post('$baseUrl/chat', options: _opts, data: {
      'userId': userId,
      'personaId': personaId,
      'text': text,
      if (conversationId != null) 'conversationId': conversationId,
    });
    return ChatResult.fromJson(resp.data as Map<String, dynamic>);
  }
}
```

- [ ] **Step 4: Run the test + commit**

Run: `flutter test test/backend_client_test.dart`
Expected: PASS.

```bash
git add app/lib/models app/lib/services/backend_client.dart app/test/backend_client_test.dart
git commit -m "feat(app): backend API client + models"
```

---

### Task 14: Speech-to-text service

**Files:**
- Create: `app/lib/services/stt_service.dart`
- Modify (Android): `app/android/app/src/main/AndroidManifest.xml` (add `RECORD_AUDIO` + microphone feature)
- Modify (iOS): `app/ios/Runner/Info.plist` (add `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`)
- Test: manual on-device (plugin needs a real mic; document the check).

**Interfaces:**
- Produces:
  - `SttService` abstraction: `Future<bool> init()`; `Future<void> startListening(void Function(String partial) onResult)`; `Future<String> stopListening()` (returns final transcript); `bool get isListening`.
  - `SpeechToTextService` implementing it via `speech_to_text`.

- [ ] **Step 1: Add platform permissions**

`AndroidManifest.xml` (inside `<manifest>`): `<uses-permission android:name="android.permission.RECORD_AUDIO"/>`.
`Info.plist`: `NSMicrophoneUsageDescription` = "Talk to your companion." and `NSSpeechRecognitionUsageDescription` = "Transcribe what you say."

- [ ] **Step 2: Implement the STT service**

```dart
// app/lib/services/stt_service.dart
import 'package:speech_to_text/speech_to_text.dart' as stt;

abstract class SttService {
  Future<bool> init();
  Future<void> startListening(void Function(String partial) onResult);
  Future<String> stopListening();
  bool get isListening;
}

class SpeechToTextService implements SttService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _lastWords = '';

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> init() => _speech.initialize();

  @override
  Future<void> startListening(void Function(String) onResult) async {
    _lastWords = '';
    await _speech.listen(onResult: (r) {
      _lastWords = r.recognizedWords;
      onResult(_lastWords);
    });
  }

  @override
  Future<String> stopListening() async {
    await _speech.stop();
    return _lastWords;
  }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze`
Expected: no errors in this file.

- [ ] **Step 4: Commit**

```bash
git add app/lib/services/stt_service.dart app/android app/ios
git commit -m "feat(app): on-device speech-to-text service + mic permissions"
```

---

### Task 15: Audio playback service + device-voice fallback

**Files:**
- Create: `app/lib/services/audio_service.dart`
- Test: `app/test/audio_service_test.dart` (tests fallback-selection logic via an injectable seam; plugin playback itself is device-only).

**Interfaces:**
- Produces:
  - `AudioService`: `Future<void> speak({Uint8List? mp3Bytes, required String fallbackText})` — plays `mp3Bytes` via `just_audio` when present, else speaks `fallbackText` via `flutter_tts`. Exposes `bool usedFallbackLast` for testability.
  - Internally decides fallback purely from whether `mp3Bytes == null`, so the decision is unit-testable without the plugins.

- [ ] **Step 1: Write the failing test** (test the decision function, not the plugins)

```dart
// app/test/audio_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/audio_service.dart';

void main() {
  test('chooses fallback when no bytes', () {
    expect(shouldUseFallback(null), true);
    expect(shouldUseFallback([1, 2, 3]), false);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/audio_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// app/lib/services/audio_service.dart
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_tts/flutter_tts.dart';

bool shouldUseFallback(List<int>? mp3Bytes) => mp3Bytes == null || mp3Bytes.isEmpty;

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool usedFallbackLast = false;

  Future<void> speak({Uint8List? mp3Bytes, required String fallbackText}) async {
    if (shouldUseFallback(mp3Bytes)) {
      usedFallbackLast = true;
      await _tts.speak(fallbackText);
      return;
    }
    usedFallbackLast = false;
    await _player.setAudioSource(_BytesSource(mp3Bytes!));
    await _player.play();
  }
}

class _BytesSource extends StreamAudioSource {
  final Uint8List _bytes;
  _BytesSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
```

- [ ] **Step 4: Run the test + commit**

Run: `flutter test test/audio_service_test.dart`
Expected: PASS.

```bash
git add app/lib/services/audio_service.dart app/test/audio_service_test.dart
git commit -m "feat(app): audio playback with device-voice fallback"
```

---

### Task 16: Conversation controller (Riverpod state machine)

**Files:**
- Create: `app/lib/state/conversation_state.dart`
- Create: `app/lib/state/conversation_controller.dart`
- Test: `app/test/conversation_controller_test.dart`

**Interfaces:**
- Consumes: `BackendClient` (Task 13), `AudioService` (Task 15), `AppSettings` (Task 12).
- Produces:
  - `TalkPhase` enum: `idle, listening, thinking, speaking, error`.
  - `ConversationState`: `phase`, `partialTranscript`, `messages: List<ChatMessage>` (each `{role, text}`), `activePersonaId`, `conversationId`, `errorMessage`.
  - `ConversationController(StateNotifier)` with `void setPersona(String id)`; `Future<void> submitUserText(String text)` (sets thinking → calls backend → appends messages → speaking → idle; on failure sets error). STT wiring is done in the screen; the controller takes final text so it is unit-testable with a fake backend + a no-op audio.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/conversation_controller_test.dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/chat_result.dart';
import 'package:app/models/persona.dart';
import 'package:app/services/backend_client.dart';
import 'package:app/state/conversation_state.dart';
import 'package:app/state/conversation_controller.dart';

class _FakeBackend implements BackendClient {
  bool fail = false;
  @override
  Future<List<Persona>> listPersonas() async => [];
  @override
  Future<ChatResult> chat({required String userId, required String personaId, required String text, String? conversationId}) async {
    if (fail) throw Exception('boom');
    return ChatResult(replyText: 'reply to $text', audioBytes: null, conversationId: conversationId ?? 'c1');
  }
}

void main() {
  test('happy path moves idle->...->idle and records messages', () async {
    final backend = _FakeBackend();
    final c = ConversationController(backend: backend, speak: (_, __) async {}, userId: 'u1', personaId: 'sage');
    await c.submitUserText('hi');
    expect(c.state.phase, TalkPhase.idle);
    expect(c.state.messages.map((m) => m.text), ['hi', 'reply to hi']);
    expect(c.state.conversationId, 'c1');
  });

  test('backend failure sets error phase', () async {
    final backend = _FakeBackend()..fail = true;
    final c = ConversationController(backend: backend, speak: (_, __) async {}, userId: 'u1', personaId: 'sage');
    await c.submitUserText('hi');
    expect(c.state.phase, TalkPhase.error);
    expect(c.state.errorMessage, isNotNull);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/conversation_controller_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// app/lib/state/conversation_state.dart
import 'package:flutter/foundation.dart';

enum TalkPhase { idle, listening, thinking, speaking, error }

@immutable
class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  const ChatMessage(this.role, this.text);
}

@immutable
class ConversationState {
  final TalkPhase phase;
  final String partialTranscript;
  final List<ChatMessage> messages;
  final String activePersonaId;
  final String? conversationId;
  final String? errorMessage;

  const ConversationState({
    required this.phase,
    required this.partialTranscript,
    required this.messages,
    required this.activePersonaId,
    required this.conversationId,
    required this.errorMessage,
  });

  ConversationState copyWith({
    TalkPhase? phase,
    String? partialTranscript,
    List<ChatMessage>? messages,
    String? activePersonaId,
    String? conversationId,
    String? errorMessage,
  }) =>
      ConversationState(
        phase: phase ?? this.phase,
        partialTranscript: partialTranscript ?? this.partialTranscript,
        messages: messages ?? this.messages,
        activePersonaId: activePersonaId ?? this.activePersonaId,
        conversationId: conversationId ?? this.conversationId,
        errorMessage: errorMessage,
      );

  static ConversationState initial(String personaId) => ConversationState(
        phase: TalkPhase.idle,
        partialTranscript: '',
        messages: const [],
        activePersonaId: personaId,
        conversationId: null,
        errorMessage: null,
      );
}
```

```dart
// app/lib/state/conversation_controller.dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/services/backend_client.dart';
import 'package:app/state/conversation_state.dart';

typedef SpeakFn = Future<void> Function(Uint8List? audio, String fallbackText);

class ConversationController extends StateNotifier<ConversationState> {
  final BackendClient backend;
  final SpeakFn speak;
  final String userId;

  ConversationController({
    required this.backend,
    required this.speak,
    required this.userId,
    required String personaId,
  }) : super(ConversationState.initial(personaId));

  void setPersona(String id) =>
      state = state.copyWith(activePersonaId: id, messages: const [], conversationId: null);

  void setPartial(String partial) => state = state.copyWith(partialTranscript: partial);
  void setListening() => state = state.copyWith(phase: TalkPhase.listening, partialTranscript: '');

  Future<void> submitUserText(String text) async {
    if (text.trim().isEmpty) {
      state = state.copyWith(phase: TalkPhase.idle);
      return;
    }
    state = state.copyWith(
      phase: TalkPhase.thinking,
      partialTranscript: '',
      messages: [...state.messages, ChatMessage('user', text)],
    );
    try {
      final res = await backend.chat(
        userId: userId,
        personaId: state.activePersonaId,
        text: text,
        conversationId: state.conversationId,
      );
      state = state.copyWith(
        phase: TalkPhase.speaking,
        conversationId: res.conversationId,
        messages: [...state.messages, ChatMessage('assistant', res.replyText)],
      );
      await speak(res.audioBytes, res.replyText);
      state = state.copyWith(phase: TalkPhase.idle);
    } catch (e) {
      state = state.copyWith(
        phase: TalkPhase.error,
        errorMessage: "Couldn't reach your companion. Tap to try again.",
      );
    }
  }
}
```

- [ ] **Step 4: Run the test + commit**

Run: `flutter test test/conversation_controller_test.dart`
Expected: PASS.

```bash
git add app/lib/state/conversation_state.dart app/lib/state/conversation_controller.dart app/test/conversation_controller_test.dart
git commit -m "feat(app): conversation controller state machine"
```

---

### Task 17: Talk screen (hold-to-talk UI) + providers wiring

**Files:**
- Create: `app/lib/state/providers.dart`
- Create: `app/lib/screens/talk_screen.dart`
- Create: `app/lib/main.dart` (replace generated)
- Test: `app/test/talk_screen_test.dart` (widget test with overridden providers)

**Interfaces:**
- Consumes: all providers/services above.
- Produces:
  - `providers.dart`: `backendClientProvider`, `audioServiceProvider`, `sttServiceProvider`, `conversationControllerProvider` (a `StateNotifierProvider` built from settings + backend + audio).
  - `TalkScreen`: shows persona name, transcript list, phase indicator, and a large press-and-hold button that starts STT on press and, on release, calls `submitUserText(finalTranscript)`.

- [ ] **Step 1: Write a widget test for phase rendering**

```dart
// app/test/talk_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/state/conversation_state.dart';
import 'package:app/state/conversation_controller.dart';
import 'package:app/state/providers.dart';
import 'package:app/screens/talk_screen.dart';
import 'package:app/services/backend_client.dart';
import 'package:app/models/persona.dart';
import 'package:app/models/chat_result.dart';

class _NoopBackend implements BackendClient {
  @override
  Future<List<Persona>> listPersonas() async => [];
  @override
  Future<ChatResult> chat({required String userId, required String personaId, required String text, String? conversationId}) async =>
      ChatResult(replyText: 'hi', audioBytes: null, conversationId: 'c1');
}

void main() {
  testWidgets('shows persona and idle hint', (tester) async {
    final controller = ConversationController(
      backend: _NoopBackend(), speak: (_, __) async {}, userId: 'u', personaId: 'sage');
    await tester.pumpWidget(ProviderScope(
      overrides: [conversationControllerProvider.overrideWith((ref) => controller)],
      child: const MaterialApp(home: TalkScreen()),
    ));
    expect(find.textContaining('sage'), findsWidgets);
    expect(find.text('Hold to talk'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/talk_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement providers**

```dart
// app/lib/state/providers.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/services/backend_client.dart';
import 'package:app/services/audio_service.dart';
import 'package:app/services/stt_service.dart';
import 'package:app/state/conversation_controller.dart';
import 'package:app/state/conversation_state.dart';
import 'package:app/state/settings_provider.dart';

final audioServiceProvider = Provider<AudioService>((ref) => AudioService());
final sttServiceProvider = Provider<SttService>((ref) => SpeechToTextService());

final backendClientProvider = Provider<BackendClient>((ref) {
  final s = ref.watch(settingsProvider);
  return DioBackendClient(Dio(), baseUrl: s.backendUrl, token: s.bearerToken);
});

final conversationControllerProvider =
    StateNotifierProvider<ConversationController, ConversationState>((ref) {
  final s = ref.watch(settingsProvider);
  final backend = ref.watch(backendClientProvider);
  final audio = ref.watch(audioServiceProvider);
  return ConversationController(
    backend: backend,
    speak: (bytes, fallback) => audio.speak(mp3Bytes: bytes, fallbackText: fallback),
    userId: s.userId,
    personaId: 'sage',
  );
});
```

- [ ] **Step 4: Implement the talk screen**

```dart
// app/lib/screens/talk_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/state/conversation_state.dart';
import 'package:app/state/providers.dart';

class TalkScreen extends ConsumerWidget {
  const TalkScreen({super.key});

  String _hint(TalkPhase p) => switch (p) {
        TalkPhase.idle => 'Hold to talk',
        TalkPhase.listening => 'Listening…',
        TalkPhase.thinking => 'Thinking…',
        TalkPhase.speaking => 'Speaking…',
        TalkPhase.error => 'Tap to retry',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationControllerProvider);
    final controller = ref.read(conversationControllerProvider.notifier);
    final stt = ref.read(sttServiceProvider);

    Future<void> onPressStart() async {
      final ok = await stt.init();
      if (!ok) return;
      controller.setListening();
      await stt.startListening(controller.setPartial);
    }

    Future<void> onPressEnd() async {
      final finalText = await stt.stopListening();
      await controller.submitUserText(finalText);
    }

    return Scaffold(
      appBar: AppBar(title: Text('Companion — ${state.activePersonaId}')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final m in state.messages)
                  Align(
                    alignment: m.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: m.role == 'user' ? Colors.blue.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m.text),
                    ),
                  ),
                if (state.partialTranscript.isNotEmpty)
                  Text(state.partialTranscript, style: const TextStyle(color: Colors.grey)),
                if (state.errorMessage != null)
                  Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(_hint(state.phase)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTapDown: (_) => onPressStart(),
                  onTapUp: (_) => onPressEnd(),
                  onTapCancel: onPressEnd,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor:
                        state.phase == TalkPhase.listening ? Colors.red : Colors.blue,
                    child: const Icon(Icons.mic, size: 40, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Implement main.dart**

```dart
// app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/screens/talk_screen.dart';

void main() => runApp(const ProviderScope(child: CompanionApp()));

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        title: 'Voice Companion',
        home: TalkScreen(),
      );
}
```

- [ ] **Step 6: Run the widget test + commit**

Run: `flutter test test/talk_screen_test.dart`
Expected: PASS.

```bash
git add app/lib/state/providers.dart app/lib/screens/talk_screen.dart app/lib/main.dart app/test/talk_screen_test.dart
git commit -m "feat(app): talk screen (hold-to-talk) + provider wiring"
```

---

### Task 18: Persona picker + settings screens

**Files:**
- Create: `app/lib/screens/persona_picker_screen.dart`
- Create: `app/lib/screens/settings_screen.dart`
- Modify: `app/lib/screens/talk_screen.dart` (add nav buttons to AppBar)
- Test: `app/test/persona_picker_test.dart`

**Interfaces:**
- Produces:
  - `PersonaPickerScreen`: loads `backend.listPersonas()`, lists them, tapping one calls `controller.setPersona(id)` and pops.
  - `SettingsScreen`: text fields for backend URL, bearer token, userId; saves via `settingsProvider.notifier.save(...)`.

- [ ] **Step 1: Write a widget test for the picker**

```dart
// app/test/persona_picker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/persona.dart';
import 'package:app/models/chat_result.dart';
import 'package:app/services/backend_client.dart';
import 'package:app/state/providers.dart';
import 'package:app/screens/persona_picker_screen.dart';

class _TwoPersonaBackend implements BackendClient {
  @override
  Future<List<Persona>> listPersonas() async => const [
        Persona(id: 'sage', name: 'Sage', description: 'calm', greeting: 'g'),
        Persona(id: 'nova', name: 'Nova', description: 'bright', greeting: 'g'),
      ];
  @override
  Future<ChatResult> chat({required String userId, required String personaId, required String text, String? conversationId}) async =>
      ChatResult(replyText: '', audioBytes: null, conversationId: 'c1');
}

void main() {
  testWidgets('lists personas from backend', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [backendClientProvider.overrideWithValue(_TwoPersonaBackend())],
      child: const MaterialApp(home: PersonaPickerScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sage'), findsOneWidget);
    expect(find.text('Nova'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/persona_picker_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the persona picker**

```dart
// app/lib/screens/persona_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/persona.dart';
import 'package:app/state/providers.dart';

class PersonaPickerScreen extends ConsumerWidget {
  const PersonaPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.read(backendClientProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a companion')),
      body: FutureBuilder<List<Persona>>(
        future: backend.listPersonas(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            children: [
              for (final p in snap.data!)
                ListTile(
                  title: Text(p.name),
                  subtitle: Text(p.description),
                  onTap: () {
                    ref.read(conversationControllerProvider.notifier).setPersona(p.id);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Implement the settings screen**

```dart
// app/lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/app_settings.dart';
import 'package:app/state/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController url, token, user;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    url = TextEditingController(text: s.backendUrl);
    token = TextEditingController(text: s.bearerToken);
    user = TextEditingController(text: s.userId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(controller: url, decoration: const InputDecoration(labelText: 'Backend URL (http://<pc-ip>:8000)')),
            TextField(controller: token, decoration: const InputDecoration(labelText: 'Bearer token')),
            TextField(controller: user, decoration: const InputDecoration(labelText: 'Your user id')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await ref.read(settingsProvider.notifier).save(AppSettings(
                      backendUrl: url.text.trim(),
                      bearerToken: token.text.trim(),
                      userId: user.text.trim().isEmpty ? 'me' : user.text.trim(),
                    ));
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ]),
        ),
      );
}
```

- [ ] **Step 5: Add nav buttons to the Talk screen AppBar**

In `talk_screen.dart`, add to the `AppBar`:
```dart
actions: [
  IconButton(icon: const Icon(Icons.people), onPressed: () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PersonaPickerScreen()))),
  IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()))),
],
```
(Add the two imports for `persona_picker_screen.dart` and `settings_screen.dart`.)

- [ ] **Step 6: Run tests + commit**

Run: `flutter test`
Expected: all PASS.

```bash
git add app/lib/screens app/test/persona_picker_test.dart
git commit -m "feat(app): persona picker + settings screens"
```

---

### Task 19: End-to-end on-device verification (Android)

**Files:**
- Modify: `app/README.md` (create) — run instructions.
- Test: manual, on the developer's Android phone.

**Interfaces:**
- Consumes: the whole system.
- Produces: a verified end-to-end voice loop and documented steps.

- [ ] **Step 1: Write the app README**

```markdown
# Voice Companion — App

## Run on your Android phone
1. Start the backend on your PC: `uvicorn app.main:app --host 0.0.0.0 --port 8000`.
2. Find your PC's LAN IP (e.g. `192.168.1.20`). Phone and PC must share Wi-Fi.
3. `cd app && flutter run` with the phone connected (USB debugging on).
4. In the app: Settings → Backend URL `http://192.168.1.20:8000`, paste the
   bearer token, set a user id → Save.
5. Grant microphone + speech permissions when prompted.
6. Hold the mic button, speak, release. You should see your text, then the
   persona's reply, and hear it (ElevenLabs voice, or the device voice if TTS
   is unset).
7. Tap the people icon to switch personas; confirm the reply voice/persona changes.
```

- [ ] **Step 2: Run the end-to-end check**

Follow the README on the real phone. Verify: transcript appears, reply text appears, audio plays, persona switch works, and pulling the PC off Wi-Fi shows the friendly error.

- [ ] **Step 3: Commit**

```bash
git add app/README.md
git commit -m "docs(app): on-device run + e2e verification steps"
```

---

### Task 20: Top-level README + wrap-up

**Files:**
- Modify: `README.md` (root)

**Interfaces:**
- Produces: a project overview linking the spec, plan, backend, and app.

- [ ] **Step 1: Update the root README**

```markdown
# Voice Companion

A cross-platform (Android + iOS) voice companion: talk out loud, it talks back
in a switchable persona that shares one intelligent, balanced Core Character
Layer, and it remembers you across sessions.

- Design spec: `docs/superpowers/specs/2026-08-17-voice-companion-design.md`
- Implementation plan: `docs/superpowers/plans/2026-08-17-voice-companion.md`
- Backend (FastAPI brain): `backend/` — see `backend/README.md`
- App (Flutter face): `app/` — see `app/README.md`

v1: tap-to-talk, on-device speech-to-text, Claude brain, ElevenLabs voice,
mem0 memory shared across personas. Wake word and streaming are planned for v2.
```

- [ ] **Step 2: Run the full backend suite one more time**

Run: `cd backend && pytest -v` → all PASS. Run: `cd app && flutter test` → all PASS.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: top-level project overview"
```

---

## Notes for the implementer

- **Order matters:** backend Tasks 1–11 stand alone and are fully TDD-testable without any device. Do them first and confirm `pytest -v` is green before touching Flutter.
- **Keys:** you can run the entire backend test suite and even boot the server with blank keys (fakes kick in). Real Claude/ElevenLabs behavior needs real keys in `.env` and real `voice_id`s in the persona YAMLs.
- **mem0:** if mem0 isn't configured with an extraction LLM + embedder, the app degrades to a no-op memory store — everything else still works. Wiring mem0 to a concrete provider is a follow-up, not a v1 blocker.
- **Deferred (v2):** background wake word, response/sentence streaming for lower latency, adaptive thinking for "go deep" moments, cloud deployment + per-user auth before any public release.
