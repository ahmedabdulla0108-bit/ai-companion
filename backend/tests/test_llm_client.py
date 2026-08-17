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
