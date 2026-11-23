from pathlib import Path
from dotenv import load_dotenv

_env_path = Path(__file__).resolve().parent.parent / ".env"
if _env_path.exists():
    load_dotenv(_env_path, override=True)

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import translate, tts, chat

app = FastAPI(title="SDG4 AI Layer", version="4.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5173"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(translate.router, prefix="/ai", tags=["translate"])
app.include_router(tts.router, prefix="/ai", tags=["tts"])
app.include_router(chat.router, prefix="/ai", tags=["chat"])

@app.get("/ai/health")
def health():
    key = (os.getenv("GEMINI_API_KEY") or "").strip()
    return {
        "status": "ok",
        "provider": "gemini",
        "gemini_key_present": bool(key),
        "gemini_key_prefix": key[:8],
        "deepl": bool((os.getenv("DEEPL_API_KEY") or "").strip()),
    }
