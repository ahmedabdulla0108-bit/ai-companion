from fastapi import APIRouter, Depends
from app.auth import require_bearer
from app.deps import get_chat_service
from app.chat_service import ChatService

router = APIRouter()

@router.get("/personas", dependencies=[Depends(require_bearer)])
def list_personas(svc: ChatService = Depends(get_chat_service)) -> list[dict]:
    return [
        {"id": p.id, "name": p.name, "description": p.description, "greeting": p.greeting}
        for p in svc.personas.values()
    ]
