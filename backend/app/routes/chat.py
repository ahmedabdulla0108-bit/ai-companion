import base64

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from app.auth import require_bearer
from app.deps import get_chat_service
from app.chat_service import ChatService
from app.providers.llm import LlmError
from app.providers.transcribe import TranscribeError

router = APIRouter()

class ChatRequest(BaseModel):
    userId: str
    personaId: str
    text: str = ""
    audio: str | None = None  # base64-encoded audio; transcribed server-side when present
    conversationId: str | None = None

class ChatResponse(BaseModel):
    replyText: str
    audio: str | None
    conversationId: str
    userText: str

@router.post("/chat", response_model=ChatResponse, dependencies=[Depends(require_bearer)])
def chat(req: ChatRequest, svc: ChatService = Depends(get_chat_service)) -> ChatResponse:
    audio_bytes = None
    if req.audio:
        try:
            audio_bytes = base64.b64decode(req.audio)
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail="audio must be valid base64")
    try:
        result = svc.handle(req.userId, req.personaId, req.text, req.conversationId, audio=audio_bytes)
    except KeyError:
        raise HTTPException(status_code=404, detail=f"Unknown persona: {req.personaId}")
    except TranscribeError:
        raise HTTPException(
            status_code=502,
            detail="Couldn't transcribe your audio right now. Please try again.",
        )
    except LlmError:
        raise HTTPException(
            status_code=502,
            detail="The companion's language model is unavailable right now. Please try again.",
        )
    return ChatResponse(
        replyText=result.reply_text,
        audio=result.audio_b64,
        conversationId=result.conversation_id,
        userText=result.user_text,
    )
