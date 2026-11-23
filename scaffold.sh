#!/usr/bin/env bash
set -euo pipefail

# ---------- Directories ----------
mkdir -p server-node/routes server-node/scrapers server-node/data/chapters
mkdir -p server-python/app/routers server-python/app/services
mkdir -p client/public/subtitles client/src/components client/src/hooks client/src/api

# ---------- Root files ----------
cat > .gitignore <<'EOF'
node_modules/
dist/
build/
.venv/
__pycache__/
*.pyc
.env
.DS_Store
*.log
EOF

cat > README.md <<'EOF'
# SDG4 Study App — Prototype

Local-only demo. No hosting, no database.

## Backends
- `server-node/`  → Express on :3000 (content API + serves built client)
- `server-python/`→ FastAPI on :8000 (translation + optional TTS)

## Frontend
- `client/` → Vite + React on :5173 (dev) or served via Node on :3000 (demo)

## First run
    cd server-node && npm install && npm run seed && npm start
    cd server-python && python -m venv .venv && source .venv/bin/activate \
      && pip install -r requirements.txt && bash run.sh
    cd client && npm install && npm run dev
EOF

# ---------- Node backend ----------
cat > server-node/package.json <<'EOF'
{
  "name": "sdg4-node-backend",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "seed": "node scrapers/seed.js",
    "scrape": "node scrapers/scrape.js"
  },
  "dependencies": {
    "axios": "^1.7.2",
    "cheerio": "^1.0.0-rc.12",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2"
  }
}
EOF

cat > server-node/.env <<'EOF'
PORT=3000
EOF

cat > server-node/server.js <<'EOF'
require("dotenv").config();
const express = require("express");
const cors = require("cors");
const path = require("path");
const contentRoutes = require("./routes/content");
const extrasRoutes = require("./routes/extras");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors({ origin: ["http://localhost:5173", "http://localhost:3000"] }));
app.use(express.json({ limit: "5mb" }));

app.use("/api", contentRoutes);
app.use("/api", extrasRoutes);
app.get("/api/health", (req, res) =>
  res.json({ status: "ok", service: "node-backend", time: new Date().toISOString() })
);

const clientDist = path.join(__dirname, "../client/dist");
app.use(express.static(clientDist));
app.get("*", (req, res) => {
  if (req.path.startsWith("/api")) return res.status(404).json({ error: "Not found" });
  res.sendFile(path.join(clientDist, "index.html"), (err) => {
    if (err) res.status(404).send("Client build not found. Run `npm run build` in /client.");
  });
});

app.listen(PORT, () => console.log(`[node] Listening on http://localhost:${PORT}`));
EOF

cat > server-node/routes/content.js <<'EOF'
const express = require("express");
const fs = require("fs");
const path = require("path");
const router = express.Router();

const chaptersDir = path.join(__dirname, "../data/chapters");
const loadChapter = (slug) => {
  const p = path.join(chaptersDir, `${slug}.json`);
  return fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, "utf-8")) : null;
};
const listChapters = () => {
  if (!fs.existsSync(chaptersDir)) return [];
  return fs.readdirSync(chaptersDir)
    .filter((f) => f.endsWith(".json"))
    .map((f) => {
      const d = JSON.parse(fs.readFileSync(path.join(chaptersDir, f), "utf-8"));
      return { slug: f.replace(".json", ""), title: d.title, subject: d.subject };
    });
};

router.get("/topics", (req, res) => res.json({ topics: listChapters() }));

router.get("/topic/:slug", (req, res) => {
  const chapter = loadChapter(req.params.slug);
  if (!chapter) return res.status(404).json({
    error: "Topic not found",
    available: listChapters().map((c) => c.slug),
  });
  res.json(chapter);
});

router.get("/search", (req, res) => {
  const q = (req.query.q || "").toLowerCase().trim();
  if (!q) return res.status(400).json({ error: "Query required" });
  const chapters = listChapters();
  const match = chapters.find(
    (c) =>
      c.slug.includes(q.replace(/\s+/g, "-")) ||
      c.title.toLowerCase().includes(q) ||
      c.subject.toLowerCase().includes(q)
  );
  if (!match) return res.status(404).json({
    error: "No demo chapter matches that topic",
    suggestion: "Try: photosynthesis, newtons-laws, python-basics",
    available: chapters.map((c) => c.slug),
  });
  res.json(loadChapter(match.slug));
});

module.exports = router;
EOF

cat > server-node/routes/extras.js <<'EOF'
const express = require("express");
const fs = require("fs");
const path = require("path");
const router = express.Router();

const dataDir = path.join(__dirname, "../data");
const readJSON = (name) => {
  const p = path.join(dataDir, name);
  return fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, "utf-8")) : null;
};
const pickByTopic = (all, topic) => (topic && all[topic] ? { [topic]: all[topic] } : all);

router.get("/exercises", (req, res) => {
  const all = readJSON("exercises.json") || {};
  res.json({ exercises: pickByTopic(all, req.query.topic) });
});
router.get("/certifications", (req, res) => {
  const all = readJSON("certifications.json") || {};
  res.json({ certifications: pickByTopic(all, req.query.topic) });
});
router.get("/resources", (req, res) => {
  const all = readJSON("resources.json") || {};
  res.json({ resources: pickByTopic(all, req.query.topic) });
});
router.get("/leaderboard", (req, res) => {
  res.json(readJSON("leaderboard.json") || { users: [] });
});

module.exports = router;
EOF

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
    sections: [
      { heading: "What is Photosynthesis?",
        body: "Photosynthesis is the process by which green plants, algae, and some bacteria convert light energy into chemical energy stored in glucose. It produces the oxygen we breathe and forms the base of most food chains.\n\nThe balanced equation:\n6CO2 + 6H2O + light -> C6H12O6 + 6O2" },
      { heading: "Where Does It Happen?",
        body: "Photosynthesis takes place inside chloroplasts, mainly in leaves. Chloroplasts contain chlorophyll, which absorbs blue and red light while reflecting green light - which is why leaves look green." },
      { heading: "Two Stages",
        body: "1. Light-dependent reactions (thylakoid membranes): light splits water, releasing oxygen and producing ATP and NADPH.\n\n2. Calvin cycle (stroma): uses ATP and NADPH to fix CO2 into glucose." },
    ],
    keyTerms: [
      { term: "Chlorophyll", definition: "Green pigment that absorbs light." },
      { term: "Chloroplast", definition: "Organelle where photosynthesis occurs." },
      { term: "ATP", definition: "Energy-carrying molecule from light reactions." },
    ],
    subtitlesUrl: "/subtitles/photosynthesis.vtt",
    videoUrl: "",
  },
  "newtons-laws": {
    slug: "newtons-laws",
    title: "Newton's Laws of Motion",
    summary: "The three foundational laws that describe motion and forces.",
    subject: "Physics",
    language: "en",
    readingTimeMinutes: 10,
    sections: [
      { heading: "First Law - Inertia", body: "An object stays at rest, or in uniform motion, unless acted on by a net external force." },
      { heading: "Second Law - F = ma", body: "Acceleration is proportional to net force and inversely proportional to mass: F = m x a." },
      { heading: "Third Law - Action & Reaction", body: "For every action there is an equal and opposite reaction." },
    ],
    keyTerms: [
      { term: "Inertia", definition: "Resistance to changes in motion." },
      { term: "Net force", definition: "Vector sum of all forces on an object." },
    ],
    subtitlesUrl: "/subtitles/newtons-laws.vtt",
    videoUrl: "",
  },
  "python-basics": {
    slug: "python-basics",
    title: "Python Basics",
    summary: "Variables, control flow, and functions.",
    subject: "Computer Science",
    language: "en",
    readingTimeMinutes: 12,
    sections: [
      { heading: "Variables", body: "Assign values to names without declaring types:\nage = 15\nname = 'Ada'" },
      { heading: "Control Flow", body: "if/elif/else for branching, for/while for loops. Indentation defines blocks." },
      { heading: "Functions", body: "Define with def, return with return:\ndef square(x):\n    return x * x" },
    ],
    keyTerms: [
      { term: "int", definition: "Integer type." },
      { term: "list", definition: "Ordered mutable sequence." },
    ],
    subtitlesUrl: "/subtitles/python-basics.vtt",
    videoUrl: "",
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
    explanation: "F = m x a = 2 x 3 = 6 N." }],
  "python-basics": [{ id: "py-ex1", type: "coding",
    question: "Write a function square(x) that returns x * x.",
    modelAnswer: "def square(x):\n    return x * x" }],
};

const certifications = {
  photosynthesis: [
    { title: "Khan Academy - Photosynthesis", url: "https://www.khanacademy.org/science/biology/photosynthesis-in-plants" },
    { title: "NPTEL - Plant Physiology", url: "https://nptel.ac.in/courses/102106053" },
  ],
  "newtons-laws": [
    { title: "Khan Academy - Forces & Newton's Laws", url: "https://www.khanacademy.org/science/physics/forces-newtons-laws" },
    { title: "MIT OCW - Classical Mechanics", url: "https://ocw.mit.edu/courses/8-01sc-classical-mechanics-fall-2016/" },
  ],
  "python-basics": [
    { title: "freeCodeCamp - Python", url: "https://www.freecodecamp.org/learn/scientific-computing-with-python/" },
    { title: "Coursera - Python for Everybody", url: "https://www.coursera.org/specializations/python" },
  ],
};

const resources = {
  photosynthesis: [{ title: "Photosynthesis - Crash Course Biology", url: "https://www.youtube.com/watch?v=uixxJtJPVXk", type: "video" }],
  "newtons-laws": [{ title: "Newton's Laws - Crash Course Physics", url: "https://www.youtube.com/watch?v=kKKM8Y-u7ds", type: "video" }],
  "python-basics": [{ title: "Python Tutorial - freeCodeCamp", url: "https://www.youtube.com/watch?v=rfscVS0vtbw", type: "video" }],
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

console.log("Seed complete. Run `npm start` next.");
EOF

cat > server-node/scrapers/scrape.js <<'EOF'
const fs = require("fs");
const path = require("path");
const axios = require("axios");
const cheerio = require("cheerio");

async function scrape(url, slug) {
  console.log(`Fetching ${url} ...`);
  const { data } = await axios.get(url, {
    headers: { "User-Agent": "SDG4StudyApp/1.0 (educational prototype)" },
    timeout: 20000,
  });
  const $ = cheerio.load(data);
  const title = $("h1").first().text().trim() || slug;
  const sections = [];

  $("h2").each((_, el) => {
    const heading = $(el).text().trim();
    let body = "";
    let next = $(el).next();
    while (next.length && !next.is("h2")) {
      if (next.is("p")) body += next.text().trim() + "\n\n";
      next = next.next();
    }
    if (heading && body.trim()) sections.push({ heading, body: body.trim() });
  });

  if (!sections.length) {
    const paras = $("p").map((_, el) => $(el).text().trim()).get().filter(Boolean);
    sections.push({ heading: "Overview", body: paras.join("\n\n") });
  }

  const chapter = {
    slug, title,
    summary: (sections[0]?.body || "").slice(0, 180) + "...",
    subject: "General", language: "en",
    readingTimeMinutes: Math.ceil(sections.reduce((s, x) => s + x.body.split(/\s+/).length, 0) / 200),
    sections, keyTerms: [],
    subtitlesUrl: `/subtitles/${slug}.vtt`, videoUrl: "",
  };

  const outDir = path.join(__dirname, "../data/chapters");
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, `${slug}.json`), JSON.stringify(chapter, null, 2));
  console.log(`Saved data/chapters/${slug}.json`);
}

const [, , url, slug] = process.argv;
if (!url || !slug) { console.log("Usage: node scrapers/scrape.js <url> <slug>"); process.exit(1); }
scrape(url, slug).catch((e) => { console.error("Scrape failed:", e.message); process.exit(1); });
EOF

# ---------- Python backend ----------
cat > server-python/requirements.txt <<'EOF'
fastapi==0.111.0
uvicorn[standard]==0.30.1
pydantic==2.7.4
python-dotenv==1.0.1
httpx==0.27.0
EOF

cat > server-python/.env <<'EOF'
# Leave blank to use mock translation / browser TTS
DEEPL_API_KEY=
TTS_API_KEY=
EOF

cat > server-python/run.sh <<'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")"
uvicorn app.main:app --reload --port 8000
EOF
chmod +x server-python/run.sh

cat > server-python/app/__init__.py <<'EOF'
EOF

cat > server-python/app/main.py <<'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import translate, tts

app = FastAPI(title="SDG4 AI Layer", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5173"],
    allow_methods=["*"], allow_headers=["*"],
)

app.include_router(translate.router, prefix="/ai", tags=["translate"])
app.include_router(tts.router, prefix="/ai", tags=["tts"])

@app.get("/ai/health")
def health():
    return {"status": "ok", "service": "fastapi-ai-layer"}
EOF

cat > server-python/app/routers/__init__.py <<'EOF'
EOF

cat > server-python/app/routers/translate.py <<'EOF'
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
EOF

cat > server-python/app/routers/tts.py <<'EOF'
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
EOF

cat > server-python/app/services/__init__.py <<'EOF'
EOF

cat > server-python/app/services/translator.py <<'EOF'
import os

def translate_text(text: str, target_language: str, source_language: str = "en") -> dict:
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
            print(f"[translate] DeepL failed: {e}. Falling back to mock.")
    return {"translated_text": f"[{target_language.upper()} MOCK] {text}",
            "target_language": target_language,
            "source_language": source_language,
            "provider": "mock"}
EOF

cat > server-python/app/services/tts_service.py <<'EOF'
import os

def synthesize(text: str, language: str = "en"):
    """
    Return audio bytes if a provider is configured, else None.
    None tells the frontend to use Web Speech API.
    """
    if not os.getenv("TTS_API_KEY"):
        return None
    # Wire a real provider here (Deepgram, ElevenLabs, Google TTS).
    return None
EOF

# ---------- Frontend scaffold ----------
cat > client/package.json <<'EOF'
{
  "name": "sdg4-client",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "axios": "^1.7.2",
    "framer-motion": "^11.3.2",
    "lenis": "^1.1.9",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.1",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.39",
    "tailwindcss": "^3.4.4",
    "vite": "^5.3.3"
  }
}
EOF

cat > client/vite.config.js <<'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:3000',
      '/ai': 'http://localhost:8000',
    },
  },
})
EOF

cat > client/index.html <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>SDG4 Study</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

cat > client/tailwind.config.js <<'EOF'
export default {
  content: ["./index.html", "./src/**/*.{js,jsx,ts,tsx}"],
  theme: {
    extend: {
      colors: {
        pistachio: '#BDDA9F',
        ink: '#141414',
        raspberry: '#E9145E',
      },
      fontFamily: {
        display: ['"Proxima Nova Condensed"', 'Oswald', 'sans-serif'],
        body: ['Sailors', '"DM Serif Display"', 'serif'],
      },
    },
  },
  plugins: [],
}
EOF

cat > client/postcss.config.js <<'EOF'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

cat > client/src/main.jsx <<'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

cat > client/src/App.jsx <<'EOF'
export default function App() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-[#FAFAF7]">
      <div className="text-center">
        <h1 className="font-display text-6xl font-bold text-ink mb-4">
          SDG4 <span className="text-raspberry">Study</span>
        </h1>
        <p className="font-body text-xl text-ink/70">
          Frontend scaffold ready. Components coming next.
        </p>
        <div className="mt-10 flex gap-4 justify-center">
          <div className="w-16 h-16 rounded-full bg-pistachio" />
          <div className="w-16 h-16 rounded-full bg-raspberry" />
          <div className="w-16 h-16 rounded-full bg-ink" />
        </div>
      </div>
    </div>
  );
}
EOF

cat > client/src/index.css <<'EOF'
/* Google Fonts fallbacks (Proxima Nova Condensed + Sailors are commercial) */
@import url('https://fonts.googleapis.com/css2?family=Oswald:wght@300;400;500;600;700&family=DM+Serif+Display:ital@0;1&display=swap');

@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --color-pistachio: #BDDA9F;
  --color-ink: #141414;
  --color-raspberry: #E9145E;
}

html, body, #root { height: 100%; margin: 0; }

body {
  background: #FAFAF7;
  color: var(--color-ink);
  font-family: 'Sailors', 'DM Serif Display', serif;
  -webkit-font-smoothing: antialiased;
}
EOF

# ---------- Subtitles ----------
cat > client/public/subtitles/photosynthesis.vtt <<'EOF'
WEBVTT

00:00:00.000 --> 00:00:05.000
Photosynthesis is how plants make food from sunlight.

00:00:05.000 --> 00:00:10.000
It happens inside chloroplasts, which contain chlorophyll.

00:00:10.000 --> 00:00:15.000
The process produces oxygen and glucose.
EOF

cat > client/public/subtitles/newtons-laws.vtt <<'EOF'
WEBVTT

00:00:00.000 --> 00:00:05.000
An object stays at rest unless acted on by a force.

00:00:05.000 --> 00:00:10.000
F equals m times a: force is mass times acceleration.

00:00:10.000 --> 00:00:15.000
Every action has an equal and opposite reaction.
EOF

cat > client/public/subtitles/python-basics.vtt <<'EOF'
WEBVTT

00:00:00.000 --> 00:00:05.000
Variables store values under names.

00:00:05.000 --> 00:00:10.000
Indentation defines code blocks in Python.

00:00:10.000 --> 00:00:15.000
Functions start with def and return with return.
EOF

echo ""
echo "✅ Scaffold complete."
echo ""
echo "Next steps:"
echo "  cd server-node && npm install && npm run seed && npm start"
echo "  cd server-python && python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt && bash run.sh"
echo "  cd client && npm install && npm run dev"