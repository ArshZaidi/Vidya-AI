from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Optional
from app.services.llm import chat as llm_chat, grade as llm_grade, _call_gemini, discover_models

router = APIRouter()

class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    context: Optional[str] = None
    language: str = "en"

class ChatResponse(BaseModel):
    reply: str

@router.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    try:
        return {"reply": llm_chat(req.messages, req.context, req.language)}
    except Exception as e:
        return {"reply": f"⚠ {str(e)[:400]}"}

class GradeRequest(BaseModel):
    question: str
    user_answer: str
    model_answer: str = ""

class GradeResponse(BaseModel):
    correct: bool
    feedback: str = ""

@router.post("/grade", response_model=GradeResponse)
def grade(req: GradeRequest):
    try:
        return llm_grade(req.question, req.user_answer, req.model_answer)
    except Exception:
        ok = req.user_answer.strip().lower() == req.model_answer.strip().lower()
        return {"correct": ok, "feedback": ""}

@router.get("/ping")
def ping():
    """Diagnostic — sends minimal request to Gemini, returns raw result or full error."""
    try:
        payload = {"contents": [{"parts": [{"text": "Reply with only the word pong."}]}]}
        data = _call_gemini(payload, timeout=20, no_think=True)
        text = data["candidates"][0]["content"]["parts"][0]["text"]
        return {
            "ok": True,
            "models_available": discover_models()[:6],
            "gemini_says": text.strip(),
        }
    except Exception as e:
        return {
            "ok": False,
            "error": str(e)[:600],
            "models_available": discover_models()[:6],
        }
