from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from app.auth import require_bearer
from app.deps import get_chat_service
from app.chat_service import ChatService

router = APIRouter()

class ChatRequest(BaseModel):
    userId: str
    personaId: str
    text: str
    conversationId: str | None = None

class ChatResponse(BaseModel):
    replyText: str
    audio: str | None
    conversationId: str

@router.post("/chat", response_model=ChatResponse, dependencies=[Depends(require_bearer)])
def chat(req: ChatRequest, svc: ChatService = Depends(get_chat_service)) -> ChatResponse:
    try:
        result = svc.handle(req.userId, req.personaId, req.text, req.conversationId)
    except KeyError:
        raise HTTPException(status_code=404, detail=f"Unknown persona: {req.personaId}")
    return ChatResponse(
        replyText=result.reply_text,
        audio=result.audio_b64,
        conversationId=result.conversation_id,
    )
