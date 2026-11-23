from fastapi import APIRouter
from fastapi.responses import Response
from pydantic import BaseModel
from app.services.tts_service import synthesize

router = APIRouter()

class TTSRequest(BaseModel):
    text: str
    language: str = "en"

@router.post("/tts")
def tts(req: TTSRequest):
    audio = synthesize(req.text, req.language)
    if audio is None:
        return {"fallback": "browser-speech-synthesis",
                "reason": "no server TTS provider configured"}
    return Response(content=audio, media_type="audio/mpeg")
