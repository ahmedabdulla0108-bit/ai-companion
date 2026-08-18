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
