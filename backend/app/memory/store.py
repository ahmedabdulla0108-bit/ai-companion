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
