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
