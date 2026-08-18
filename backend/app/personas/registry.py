from dataclasses import dataclass
from pathlib import Path
import yaml

@dataclass
class Persona:
    id: str
    name: str
    description: str
    system_prompt: str
    voice_id: str          # ElevenLabs voice id
    model: str
    max_tokens: int
    greeting: str
    kokoro_voice: str = ""  # Kokoro voice name (used when tts_provider=kokoro)

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
            kokoro_voice=data.get("kokoro_voice", ""),
        )
        personas[persona.id] = persona
    return personas

def effective_system_prompt(core: str, persona: Persona, memories: list[str]) -> str:
    parts = [core, persona.system_prompt]
    if memories:
        rendered = "\n".join(f"- {m}" for m in memories)
        parts.append(f"What you remember about the person you're talking to:\n{rendered}")
    return "\n\n".join(parts)
