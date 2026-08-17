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
