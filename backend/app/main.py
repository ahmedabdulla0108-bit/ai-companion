from fastapi import FastAPI

app = FastAPI(title="Voice Companion Backend")

@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
