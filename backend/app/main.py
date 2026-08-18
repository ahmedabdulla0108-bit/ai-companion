from fastapi import FastAPI
from app.routes import personas, chat

app = FastAPI(title="Voice Companion Backend")

@app.get("/health")
def health() -> dict:
    return {"status": "ok"}

app.include_router(personas.router)
app.include_router(chat.router)
