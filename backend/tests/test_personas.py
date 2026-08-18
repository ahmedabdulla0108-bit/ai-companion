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
