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
