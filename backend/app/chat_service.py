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
