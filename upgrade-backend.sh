#!/usr/bin/env bash
set -euo pipefail

# --- Dependencies ---
cat > server-python/requirements.txt <<'EOF'
fastapi>=0.136
uvicorn[standard]>=0.30
pydantic>=2.13
python-dotenv>=1.0
httpx>=0.27
google-genai>=1.0
EOF

# --- .env template ---
cat > server-python/.env <<'EOF'
# Paste your Gemini key below (https://aistudio.google.com/apikey)
GEMINI_API_KEY=
# Optional — leave blank to use Gemini for translation
DEEPL_API_KEY=
EOF

# --- LLM service ---
cat > server-python/app/services/llm.py <<'EOF'
import os

_client = None

def get_client():
    global _client
    if _client is None:
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise RuntimeError("GEMINI_API_KEY not set in server-python/.env")
        from google import genai
        _client = genai.Client(api_key=api_key)
    return _client

def chat(messages, context=None, language="en"):
    client = get_client()
    system = (
        "You are a patient, friendly tutor helping a student understand a chapter. "
        "Be concise. Use short paragraphs. If asked to explain something, give a "
        "clear example. Keep responses under 180 words unless the student asks for depth."
    )
    if language and language != "en":
        system += f" Respond in language code '{language}'."
    if context:
        system += f"\n\nChapter being studied:\n{context[:8000]}"

    contents = [
        {"role": "user" if m.role == "user" else "model",
         "parts": [{"text": m.content}]}
        for m in messages
    ]

    resp = client.models.generate_content(
        model="gemini-2.0-flash",
        contents=contents,
        config={"system_instruction": system},
    )
    return resp.text

def grade(question, user_answer, model_answer):
    client = get_client()
    prompt = f"""Grade this student's answer.

Question: {question}
Reference answer: {model_answer}
Student answer: {user_answer}

Return ONLY JSON in this shape:
{{"correct": true|false, "feedback": "one short sentence of feedback"}}

Be lenient — accept paraphrases and equivalent answers."""
    resp = client.models.generate_content(
        model="gemini-2.0-flash",
        contents=prompt,
        config={"response_mime_type": "application/json"},
    )
    import json
    try:
        return json.loads(resp.text)
    except Exception:
        ok = user_answer.strip().lower() == str(model_answer).strip().lower()
        return {"correct": ok, "feedback": ""}
EOF

# --- Chat router ---
cat > server-python/app/routers/chat.py <<'EOF'
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from app.services.llm import chat as llm_chat, grade as llm_grade

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
        raise HTTPException(status_code=500, detail=str(e))

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
    except Exception as e:
        # Fallback: naive string compare
        ok = req.user_answer.strip().lower() == req.model_answer.strip().lower()
        return {"correct": ok, "feedback": ""}
EOF

# --- Translator: Gemini fallback ---
cat > server-python/app/services/translator.py <<'EOF'
import os

def translate_text(text: str, target_language: str, source_language: str = "en") -> dict:
    # 1) DeepL if configured
    deepl_key = os.getenv("DEEPL_API_KEY")
    if deepl_key and target_language != source_language:
        try:
            import httpx
            resp = httpx.post(
                "https://api-free.deepl.com/v2/translate",
                headers={"Authorization": f"DeepL-Auth-Key {deepl_key}"},
                data={"text": text,
                      "source_lang": source_language.upper(),
                      "target_lang": target_language.upper()},
                timeout=20,
            )
            resp.raise_for_status()
            return {"translated_text": resp.json()["translations"][0]["text"],
                    "target_language": target_language,
                    "source_language": source_language,
                    "provider": "deepl"}
        except Exception as e:
            print(f"[translate] DeepL failed: {e}")

    # 2) Gemini if configured
    if os.getenv("GEMINI_API_KEY") and target_language != source_language:
        try:
            from app.services.llm import get_client
            client = get_client()
            resp = client.models.generate_content(
                model="gemini-2.0-flash",
                contents=(
                    f"Translate the following text to language code '{target_language}'. "
                    f"Return only the translation, no explanation, no quotes:\n\n{text}"
                ),
            )
            return {"translated_text": resp.text.strip(),
                    "target_language": target_language,
                    "source_language": source_language,
                    "provider": "gemini"}
        except Exception as e:
            print(f"[translate] Gemini failed: {e}")

    return {"translated_text": f"[{target_language.upper()} MOCK] {text}",
            "target_language": target_language,
            "source_language": source_language,
            "provider": "mock"}
EOF

# --- main.py: register chat router ---
cat > server-python/app/main.py <<'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import translate, tts, chat

app = FastAPI(title="SDG4 AI Layer", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5173"],
    allow_methods=["*"], allow_headers=["*"],
)

app.include_router(translate.router, prefix="/ai", tags=["translate"])
app.include_router(tts.router, prefix="/ai", tags=["tts"])
app.include_router(chat.router, prefix="/ai", tags=["chat"])

@app.get("/ai/health")
def health():
    import os
    return {
        "status": "ok",
        "service": "fastapi-ai-layer",
        "gemini": bool(os.getenv("GEMINI_API_KEY")),
        "deepl": bool(os.getenv("DEEPL_API_KEY")),
    }
EOF

# --- Updated seed with youtubeId + tables ---
cat > server-node/scrapers/seed.js <<'EOF'
const fs = require("fs");
const path = require("path");

const dataDir = path.join(__dirname, "../data");
const chaptersDir = path.join(dataDir, "chapters");
fs.mkdirSync(chaptersDir, { recursive: true });

const chapters = {
  photosynthesis: {
    slug: "photosynthesis",
    title: "Photosynthesis",
    summary: "How plants convert light energy into chemical energy stored in glucose.",
    subject: "Biology",
    language: "en",
    readingTimeMinutes: 8,
    youtubeId: "uixxJtJPVXk",
    subtitlesUrl: "/subtitles/photosynthesis.vtt",
    sections: [
      { heading: "What is Photosynthesis?",
        body: "Photosynthesis is the process by which green plants, algae, and some bacteria convert light energy into chemical energy stored in glucose. It produces the oxygen we breathe and forms the base of most food chains.\n\n6CO2 + 6H2O + light → C6H12O6 + 6O2" },
      { heading: "Where Does It Happen?",
        body: "Photosynthesis takes place inside chloroplasts, mainly in leaves. Chloroplasts contain chlorophyll, which absorbs blue and red light while reflecting green light — which is why leaves look green." },
      { heading: "Two Stages at a Glance",
        type: "table",
        headers: ["Stage", "Location", "Inputs", "Outputs"],
        rows: [
          ["Light-dependent reactions", "Thylakoid membrane", "H2O, light, ADP, NADP+", "O2, ATP, NADPH"],
          ["Calvin cycle", "Stroma", "CO2, ATP, NADPH", "Glucose (G3P), ADP, NADP+"],
        ] },
      { heading: "Why It Matters",
        body: "Photosynthesis is the primary source of all food on Earth and the main source of oxygen in the atmosphere. Without it, complex life as we know it would not exist." },
    ],
    keyTerms: [
      { term: "Chlorophyll", definition: "Green pigment that absorbs light." },
      { term: "Chloroplast", definition: "Organelle where photosynthesis occurs." },
      { term: "ATP", definition: "Energy-carrying molecule from light reactions." },
    ],
  },
  "newtons-laws": {
    slug: "newtons-laws",
    title: "Newton's Laws of Motion",
    summary: "The three foundational laws that describe motion and forces.",
    subject: "Physics",
    language: "en",
    readingTimeMinutes: 10,
    youtubeId: "kKKM8Y-u7ds",
    subtitlesUrl: "/subtitles/newtons-laws.vtt",
    sections: [
      { heading: "First Law — Inertia",
        body: "An object stays at rest, or in uniform motion, unless acted on by a net external force. This is why passengers jerk forward when a bus brakes suddenly." },
      { heading: "Second Law — F = ma",
        body: "Acceleration is proportional to net force and inversely proportional to mass: F = m × a." },
      { heading: "Third Law — Action & Reaction",
        body: "For every action there is an equal and opposite reaction. When you push a wall, the wall pushes back with the same force." },
      { heading: "Summary Table",
        type: "table",
        headers: ["Law", "Statement", "Example"],
        rows: [
          ["1st", "Object in motion stays in motion", "Coffee cup sliding on a car dashboard"],
          ["2nd", "F = m × a", "Heavier cart needs more force to accelerate"],
          ["3rd", "Equal and opposite reaction", "Rocket pushes gas down, gas pushes rocket up"],
        ] },
    ],
    keyTerms: [
      { term: "Inertia", definition: "Resistance to changes in motion." },
      { term: "Net force", definition: "Vector sum of all forces on an object." },
    ],
  },
  "python-basics": {
    slug: "python-basics",
    title: "Python Basics",
    summary: "Variables, control flow, and functions.",
    subject: "Computer Science",
    language: "en",
    readingTimeMinutes: 12,
    youtubeId: "rfscVS0vtbw",
    subtitlesUrl: "/subtitles/python-basics.vtt",
    sections: [
      { heading: "Variables", body: "Assign values to names without declaring types:\nage = 15\nname = 'Ada'" },
      { heading: "Control Flow", body: "if/elif/else for branching, for/while for loops. Indentation defines blocks." },
      { heading: "Functions", body: "Define with def, return with return:\ndef square(x):\n    return x * x" },
      { heading: "Data Types",
        type: "table",
        headers: ["Type", "Example", "Mutable?"],
        rows: [
          ["int", "42", "No"],
          ["str", "'hello'", "No"],
          ["list", "[1, 2, 3]", "Yes"],
          ["dict", "{'a': 1}", "Yes"],
        ] },
    ],
    keyTerms: [
      { term: "int", definition: "Integer type." },
      { term: "list", definition: "Ordered mutable sequence." },
    ],
  },
};

for (const [slug, ch] of Object.entries(chapters)) {
  fs.writeFileSync(path.join(chaptersDir, `${slug}.json`), JSON.stringify(ch, null, 2));
}

const exercises = {
  photosynthesis: [{ id: "photo-ex1", type: "multiple-choice",
    question: "Which organelle is the main site of photosynthesis?",
    options: ["Mitochondrion", "Chloroplast", "Nucleus", "Ribosome"],
    answer: "Chloroplast",
    explanation: "Chloroplasts contain chlorophyll and host both stages." }],
  "newtons-laws": [{ id: "nl-ex1", type: "multiple-choice",
    question: "A 2 kg object accelerates at 3 m/s². What is the net force?",
    options: ["1.5 N", "5 N", "6 N", "0.67 N"],
    answer: "6 N",
    explanation: "F = m × a = 2 × 3 = 6 N." }],
  "python-basics": [{ id: "py-ex1", type: "coding",
    question: "Write a function square(x) that returns x * x.",
    modelAnswer: "def square(x):\n    return x * x" }],
};

const certifications = {
  photosynthesis: [
    { title: "Khan Academy — Photosynthesis", url: "https://www.khanacademy.org/science/biology/photosynthesis-in-plants" },
    { title: "NPTEL — Plant Physiology", url: "https://nptel.ac.in/courses/102106053" }],
  "newtons-laws": [
    { title: "Khan Academy — Forces & Newton's Laws", url: "https://www.khanacademy.org/science/physics/forces-newtons-laws" },
    { title: "MIT OCW — Classical Mechanics", url: "https://ocw.mit.edu/courses/8-01sc-classical-mechanics-fall-2016/" }],
  "python-basics": [
    { title: "freeCodeCamp — Python", url: "https://www.freecodecamp.org/learn/scientific-computing-with-python/" },
    { title: "Coursera — Python for Everybody", url: "https://www.coursera.org/specializations/python" }],
};

const resources = {
  photosynthesis: [{ title: "Photosynthesis — Crash Course Biology", url: "https://www.youtube.com/watch?v=uixxJtJPVXk", type: "video" }],
  "newtons-laws": [{ title: "Newton's Laws — Crash Course Physics", url: "https://www.youtube.com/watch?v=kKKM8Y-u7ds", type: "video" }],
  "python-basics": [{ title: "Python Tutorial — freeCodeCamp", url: "https://www.youtube.com/watch?v=rfscVS0vtbw", type: "video" }],
};

const leaderboard = { users: [
  { name: "Aarav", xp: 2400, credits: 120, rank: 1 },
  { name: "Mei", xp: 2100, credits: 100, rank: 2 },
  { name: "Diego", xp: 1850, credits: 90, rank: 3 },
  { name: "Fatima", xp: 1600, credits: 75, rank: 4 },
  { name: "You (demo)", xp: 0, credits: 0, rank: 5, isDemoUser: true },
]};

fs.writeFileSync(path.join(dataDir, "exercises.json"), JSON.stringify(exercises, null, 2));
fs.writeFileSync(path.join(dataDir, "certifications.json"), JSON.stringify(certifications, null, 2));
fs.writeFileSync(path.join(dataDir, "resources.json"), JSON.stringify(resources, null, 2));
fs.writeFileSync(path.join(dataDir, "leaderboard.json"), JSON.stringify(leaderboard, null, 2));

console.log("Seed complete with YouTube IDs and tables.");
EOF

echo "✅ Backend upgraded."