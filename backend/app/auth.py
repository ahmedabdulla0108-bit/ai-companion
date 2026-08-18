from fastapi import Depends, Header, HTTPException

from app.config import Settings, get_settings


def verify_token(authorization: str | None, expected: str) -> None:
    if not authorization or authorization != f"Bearer {expected}":
        raise HTTPException(status_code=401, detail="Unauthorized")


def require_bearer(
    authorization: str | None = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> None:
    verify_token(authorization, expected=settings.app_bearer_token)
