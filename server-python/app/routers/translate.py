from fastapi import APIRouter
from pydantic import BaseModel
from app.services.translator import translate_text

router = APIRouter()

class TranslateRequest(BaseModel):
    text: str
    target_language: str
    source_language: str = "en"

class TranslateResponse(BaseModel):
    translated_text: str
    target_language: str
    source_language: str
    provider: str

@router.post("/translate", response_model=TranslateResponse)
def translate(req: TranslateRequest):
    return translate_text(req.text, req.target_language, req.source_language)
