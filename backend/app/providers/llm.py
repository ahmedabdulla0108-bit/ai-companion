from typing import Protocol

import httpx


class LlmError(RuntimeError):
    """Raised when the upstream LLM provider call fails (rate limit, timeout,
    connection error, API error). Lets the route return a distinct 502 (bad
    gateway) instead of an undifferentiated 500, so a provider outage is
    distinguishable from an application defect."""


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
        self._anthropic = anthropic
        self._client = anthropic.Anthropic(api_key=api_key)

    def complete(self, system: str, messages: list[dict], model: str, max_tokens: int) -> str:
        # No `thinking` param on purpose — keeps voice latency low (Opus 4.8
        # runs without thinking when omitted).
        try:
            resp = self._client.messages.create(
                model=model,
                max_tokens=max_tokens,
                system=system,
                messages=messages,
            )
        except self._anthropic.APIError as e:
            # Rate limit / timeout / connection / API status errors all subclass
            # APIError. Surface as a provider error so the route maps it to 502.
            raise LlmError(f"LLM provider request failed: {e}") from e
        for block in resp.content:
            if block.type == "text":
                return block.text
        return ""


class OpenAiCompatLlmClient:
    """LLM client for any OpenAI-compatible chat/completions gateway (e.g.
    OmniRoute). Prepends the system prompt as a system message. When
    model_override is set it is used instead of the per-persona model, so a
    single gateway model can serve every persona."""

    def __init__(self, base_url: str, api_key: str, model_override: str = "", timeout: float = 60.0):
        self._base_url = base_url.rstrip("/")
        self._api_key = api_key
        self._model_override = model_override
        self._timeout = timeout

    def complete(self, system: str, messages: list[dict], model: str, max_tokens: int) -> str:
        payload_messages = [{"role": "system", "content": system}, *messages]
        headers = {"content-type": "application/json"}
        if self._api_key:
            headers["Authorization"] = f"Bearer {self._api_key}"
        try:
            resp = httpx.post(
                f"{self._base_url}/chat/completions",
                headers=headers,
                json={
                    "model": self._model_override or model,
                    "max_tokens": max_tokens,
                    "messages": payload_messages,
                },
                timeout=self._timeout,
            )
            resp.raise_for_status()
            data = resp.json()
            return data["choices"][0]["message"]["content"] or ""
        except Exception as e:  # noqa: BLE001 - surface as provider error → 502
            raise LlmError(f"OpenAI-compatible LLM request failed: {e}") from e
