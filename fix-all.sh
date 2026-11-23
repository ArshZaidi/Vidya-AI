#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 1. BACKEND — Replace SDK with direct REST (fixes 500)
# ============================================================

cat > server-python/app/services/llm.py <<'PYEOF'
import os, json, httpx

MODEL_CANDIDATES = ["gemini-2.0-flash", "gemini-1.5-flash"]

def _api_key():
    key = os.getenv("GEMINI_API_KEY", "").strip()
    if not key:
        raise RuntimeError(
            "GEMINI_API_KEY missing. Open server-python/.env and paste your key, then restart FastAPI."
        )
    return key

def _call_gemini(payload, timeout=30):
    key = _api_key()
    last_err = None
    for model in MODEL_CANDIDATES:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        try:
            with httpx.Client(timeout=timeout) as client:
                r = client.post(url, params={"key": key}, json=payload)
            if r.status_code == 200:
                return r.json()
            last_err = f"{model} → HTTP {r.status_code}: {r.text[:300]}"
        except Exception as e:
            last_err = f"{model} → {e}"
    raise RuntimeError(last_err or "Gemini call failed")

def chat(messages, context=None, language="en"):
    system = (
        "You are a patient, friendly tutor helping a student understand a chapter. "
        "Be concise. Use short paragraphs. Give examples when helpful. "
        "Keep responses under 180 words unless asked for depth."
    )
    if language and language != "en":
        system += f" Respond entirely in language code '{language}'."
    if context:
        system += f"\n\nChapter being studied:\n{context[:8000]}"

    contents = []
    for m in messages:
        contents.append({
            "role": "user" if m.role == "user" else "model",
            "parts": [{"text": m.content}],
        })

    payload = {
        "systemInstruction": {"parts": [{"text": system}]},
        "contents": contents,
        "generationConfig": {"temperature": 0.7, "maxOutputTokens": 600},
    }
    data = _call_gemini(payload)
    try:
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError):
        raise RuntimeError(f"Unexpected Gemini shape: {json.dumps(data)[:300]}")

def grade(question, user_answer, model_answer):
    prompt = f"""Grade this student's answer.

Question: {question}
Reference answer: {model_answer}
Student answer: {user_answer}

Return ONLY valid JSON:
{{"correct": true|false, "feedback": "one short sentence"}}

Accept paraphrases and equivalent answers."""
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.1,
            "maxOutputTokens": 200,
            "responseMimeType": "application/json",
        },
    }
    try:
        data = _call_gemini(payload)
        text = data["candidates"][0]["content"]["parts"][0]["text"]
        return json.loads(text)
    except Exception:
        return {"correct": user_answer.strip().lower() == str(model_answer).strip().lower(),
                "feedback": ""}
PYEOF

cat > server-python/app/routers/chat.py <<'PYEOF'
from fastapi import APIRouter
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
        # Never 500 — surface the real reason inside the chat bubble
        return {"reply": f"⚠ AI error: {str(e)[:280]}"}

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
PYEOF

# Rewrite translator to use REST (same pattern)
cat > server-python/app/services/translator.py <<'PYEOF'
import os, httpx

def translate_text(text: str, target_language: str, source_language: str = "en") -> dict:
    if target_language == source_language or not text.strip():
        return {"translated_text": text, "target_language": target_language,
                "source_language": source_language, "provider": "passthrough"}

    # 1. DeepL
    deepl_key = os.getenv("DEEPL_API_KEY")
    if deepl_key:
        try:
            r = httpx.post(
                "https://api-free.deepl.com/v2/translate",
                headers={"Authorization": f"DeepL-Auth-Key {deepl_key}"},
                data={"text": text,
                      "source_lang": source_language.upper(),
                      "target_lang": target_language.upper()},
                timeout=20,
            )
            if r.status_code == 200:
                return {"translated_text": r.json()["translations"][0]["text"],
                        "target_language": target_language,
                        "source_language": source_language, "provider": "deepl"}
        except Exception as e:
            print(f"[translate] DeepL: {e}")

    # 2. Gemini
    gemini_key = os.getenv("GEMINI_API_KEY", "").strip()
    if gemini_key:
        try:
            url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
            payload = {
                "contents": [{"parts": [{"text":
                    f"Translate the following text to language code '{target_language}'. "
                    f"Return ONLY the translated text, no quotes, no explanation:\n\n{text}"
                }]}],
                "generationConfig": {"temperature": 0.1, "maxOutputTokens": 3000},
            }
            with httpx.Client(timeout=30) as client:
                r = client.post(url, params={"key": gemini_key}, json=payload)
            if r.status_code == 200:
                body = r.json()
                out = body["candidates"][0]["content"]["parts"][0]["text"].strip()
                return {"translated_text": out, "target_language": target_language,
                        "source_language": source_language, "provider": "gemini"}
            print(f"[translate] Gemini HTTP {r.status_code}: {r.text[:200]}")
        except Exception as e:
            print(f"[translate] Gemini: {e}")

    return {"translated_text": f"[{target_language.upper()} MOCK] {text}",
            "target_language": target_language,
            "source_language": source_language, "provider": "mock"}
PYEOF

# ============================================================
# 2. FRONTEND — Kia Seltos HTX palette + per-language fonts
# ============================================================

# Update index.html — add inline theme script + Devanagari-focused font stack
cat > client/index.html <<'HTMLEOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <script>
      (function () {
        try {
          var t = localStorage.getItem('sdg4-theme');
          if (t === 'dark') document.documentElement.classList.add('dark');
        } catch (e) {}
      })();
    </script>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Oswald:wght@400;500;600;700&family=DM+Serif+Display:ital@0;1&family=Noto+Sans+Devanagari:wght@400;500;600;700&family=Noto+Sans+Bengali:wght@400;500;600;700&family=Noto+Sans+Tamil:wght@400;500;600;700&family=Noto+Sans+Telugu:wght@400;500;600;700&family=Noto+Sans+Kannada:wght@400;500;600;700&family=Noto+Sans+Malayalam:wght@400;500;600;700&family=Noto+Sans+Gujarati:wght@400;500;600;700&family=Noto+Sans+Gurmukhi:wght@400;500;600;700&family=Noto+Nastaliq+Urdu:wght@400;500;600;700&family=Noto+Sans+Oriya:wght@400;500;600;700&display=swap" rel="stylesheet">
    <title>SDG4 Study</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
HTMLEOF

# Update index.css — Kia palette + script fonts
cat > client/src/index.css <<'CSSEOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

/* ---- Kia Seltos HTX inspired palette ---- */
:root {
  /* Warm cream interior, deep charcoal, bronze accents, raspberry pop */
  --ink-rgb: 28 27 25;          /* #1c1b19 warm deep charcoal */
  --bg-rgb: 245 239 228;        /* #f5efe4 warm cream interior */
  --surface-rgb: 251 247 239;   /* #fbf7ef lighter cream */
  --pistachio-rgb: 201 178 138; /* #c9b28a warm tan (seat insert) */
  --raspberry-rgb: 233 20 94;   /* #e9145e brand pop */
  --bronze-rgb: 138 90 43;      /* #8a5a2b deep copper trim */
}

.dark {
  /* Night cabin — deep charcoal with warm bronze */
  --ink-rgb: 240 232 216;       /* #f0e8d8 warm cream white */
  --bg-rgb: 14 13 12;           /* #0e0d0c near black warm */
  --surface-rgb: 26 25 23;      /* #1a1917 dark charcoal */
  --pistachio-rgb: 184 160 116; /* #b8a074 muted tan */
  --raspberry-rgb: 255 77 106;  /* #ff4d6a brighter rose */
  --bronze-rgb: 200 136 74;     /* #c8884a bright copper */
}

html, body, #root { height: 100%; margin: 0; }

body {
  background: rgb(var(--bg-rgb));
  color: rgb(var(--ink-rgb));
  font-family: 'DM Serif Display', Georgia, serif;
  -webkit-font-smoothing: antialiased;
  transition: background 200ms ease, color 200ms ease;
}

/* ---- Per-language content fonts ----
   Noto first ⇒ any Latin glyphs render in Noto's Latin style,
   which is visibly different from DM Serif. Then Devanagari/
   Bengali/etc glyphs render in their native Noto script. */
.content-en { font-family: 'DM Serif Display', Georgia, serif; }
.content-hi,
.content-mr { font-family: 'Noto Sans Devanagari', 'DM Serif Display', Georgia, sans-serif; }
.content-bn { font-family: 'Noto Sans Bengali', 'DM Serif Display', Georgia, sans-serif; }
.content-ta { font-family: 'Noto Sans Tamil', 'DM Serif Display', Georgia, sans-serif; }
.content-te { font-family: 'Noto Sans Telugu', 'DM Serif Display', Georgia, sans-serif; }
.content-kn { font-family: 'Noto Sans Kannada', 'DM Serif Display', Georgia, sans-serif; }
.content-ml { font-family: 'Noto Sans Malayalam', 'DM Serif Display', Georgia, sans-serif; }
.content-gu { font-family: 'Noto Sans Gujarati', 'DM Serif Display', Georgia, sans-serif; }
.content-pa { font-family: 'Noto Sans Gurmukhi', 'DM Serif Display', Georgia, sans-serif; }
.content-ur { font-family: 'Noto Nastaliq Urdu', 'DM Serif Display', Georgia, serif; }
.content-or { font-family: 'Noto Sans Oriya', 'DM Serif Display', Georgia, sans-serif; }

/* Apply the content font to any child when a wrapper has a lang class */
.content-hi *, .content-mr *,
.content-bn *, .content-ta *,
.content-te *, .content-kn *,
.content-ml *, .content-gu *,
.content-pa *, .content-ur *,
.content-or * { font-family: inherit; }

::selection { background: rgb(var(--raspberry-rgb)); color: white; }

::-webkit-scrollbar { width: 8px; height: 8px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: rgb(var(--ink-rgb) / 0.15); border-radius: 4px; }
::-webkit-scrollbar-thumb:hover { background: rgb(var(--raspberry-rgb)); }

.no-scrollbar::-webkit-scrollbar { display: none; }
.no-scrollbar { scrollbar-width: none; }
CSSEOF

# Tailwind — add bronze
cat > client/tailwind.config.js <<'TSEOF'
export default {
  darkMode: 'class',
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: {
        pistachio: 'rgb(var(--pistachio-rgb) / <alpha-value>)',
        ink: 'rgb(var(--ink-rgb) / <alpha-value>)',
        raspberry: 'rgb(var(--raspberry-rgb) / <alpha-value>)',
        bronze: 'rgb(var(--bronze-rgb) / <alpha-value>)',
        bg: 'rgb(var(--bg-rgb) / <alpha-value>)',
        surface: 'rgb(var(--surface-rgb) / <alpha-value>)',
      },
      fontFamily: {
        display: ['"Proxima Nova Condensed"', 'Oswald', 'sans-serif'],
        body: ['Sailors', '"DM Serif Display"', 'serif'],
      },
    },
  },
};
TSEOF

# Language constants — font now used as a fallback hint only
cat > client/src/constants/languages.js <<'JSEOF'
export const LANGUAGES = [
  { code: 'en', label: 'EN',   name: 'English' },
  { code: 'hi', label: 'हिं',  name: 'हिन्दी' },
  { code: 'bn', label: 'বাং',  name: 'বাংলা' },
  { code: 'mr', label: 'मरा',  name: 'मराठी' },
  { code: 'ta', label: 'த',    name: 'தமிழ்' },
  { code: 'te', label: 'తె',   name: 'తెలుగు' },
  { code: 'kn', label: 'ಕ',    name: 'ಕನ್ನಡ' },
  { code: 'ml', label: 'മ',    name: 'മലയാളം' },
  { code: 'gu', label: 'ગુ',   name: 'ગુજરાતી' },
  { code: 'pa', label: 'ਪੰ',   name: 'ਪੰਜਾਬੀ' },
  { code: 'ur', label: 'اردو', name: 'اُردُو' },
  { code: 'or', label: 'ଓ',    name: 'ଓଡ଼ିଆ' },
];

export const getLang = (code) =>
  LANGUAGES.find((l) => l.code === code) || LANGUAGES[0];
JSEOF

# ChapterViewer — wrapper class drives fonts
cat > client/src/components/ChapterViewer.jsx <<'JSXEOF'
import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { api } from '../api/client';
import { useLang } from '../contexts/LangContext';
import LanguageToggle from './LanguageToggle';
import MagneticButton from './MagneticButton';

export default function ChapterViewer({ chapter }) {
  const { lang, setLang } = useLang();
  const [sections, setSections] = useState(chapter.sections);
  const [translating, setTranslating] = useState(false);
  const [speaking, setSpeaking] = useState(false);

  useEffect(() => { setSections(chapter.sections); }, [chapter]);

  const translateAll = async (target) => {
    setLang(target);
    if (target === 'en') { setSections(chapter.sections); return; }
    setTranslating(true);
    try {
      const translated = await Promise.all(chapter.sections.map(async (s) => {
        if (s.type === 'table') {
          const [heading, headers, ...rows] = await Promise.all([
            api.translate(s.heading, target).then(r => r.data.translated_text),
            Promise.all(s.headers.map(h => api.translate(h, target).then(r => r.data.translated_text))),
            ...s.rows.map(row => Promise.all(row.map(cell => api.translate(cell, target).then(r => r.data.translated_text)))),
          ]);
          return { ...s, heading, headers, rows };
        }
        const [h, b] = await Promise.all([
          api.translate(s.heading, target),
          api.translate(s.body || '', target),
        ]);
        return { ...s, heading: h.data.translated_text, body: b.data.translated_text };
      }));
      setSections(translated);
    } catch { setSections(chapter.sections); }
    finally { setTranslating(false); }
  };

  const speak = () => {
    if (!('speechSynthesis' in window)) return;
    if (speaking) { window.speechSynthesis.cancel(); setSpeaking(false); return; }
    const text = sections.map(s => s.type === 'table' ? s.heading : `${s.heading}. ${s.body || ''}`).join('. ');
    const u = new SpeechSynthesisUtterance(text);
    u.lang = { hi:'hi-IN', mr:'hi-IN', bn:'bn-IN', ta:'ta-IN', te:'te-IN',
               kn:'kn-IN', ml:'ml-IN', gu:'gu-IN', pa:'pa-IN', ur:'ur-IN' }[lang] || 'en-US';
    u.onend = () => setSpeaking(false);
    window.speechSynthesis.speak(u);
    setSpeaking(true);
  };

  const downloadNotes = () => {
    const md = `# ${chapter.title}\n\n${sections.map(s => {
      if (s.type === 'table') {
        const head = `| ${s.headers.join(' | ')} |\n| ${s.headers.map(() => '---').join(' | ')} |`;
        const body = s.rows.map(r => `| ${r.join(' | ')} |`).join('\n');
        return `## ${s.heading}\n\n${head}\n${body}`;
      }
      return `## ${s.heading}\n\n${s.body}`;
    }).join('\n\n')}`;
    const blob = new Blob([md], { type: 'text/markdown' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = `${chapter.slug}-notes.md`; a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <motion.article
      key={lang}
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4 }}
      className={`content-${lang}`}
    >
      <div className="flex flex-wrap items-end justify-between gap-4 mb-6">
        <div>
          <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry">
            {chapter.subject} · {chapter.readingTimeMinutes} min read
          </p>
          <h2 className="font-body text-5xl md:text-6xl mt-2 leading-[0.95]">
            {chapter.title}
          </h2>
        </div>
        <LanguageToggle value={lang} onChange={translateAll} />
      </div>

      <div className="flex flex-wrap gap-3 mb-10">
        <MagneticButton onClick={speak}
          className="px-6 py-2.5 bg-ink text-bg rounded-full font-display text-sm tracking-wider">
          {speaking ? '◼ Stop' : '▶ Listen'}
        </MagneticButton>
        <MagneticButton onClick={downloadNotes}
          className="px-6 py-2.5 bg-pistachio text-ink rounded-full font-display text-sm tracking-wider">
          ↓ Download Notes
        </MagneticButton>
      </div>

      <div className={`space-y-10 ${translating ? 'opacity-50 transition-opacity' : ''}`}>
        {sections.map((s, i) => (
          <motion.section key={i}
            initial={{ opacity: 0, y: 14 }} whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.45, delay: i * 0.04 }}>
            <h3 className="font-display text-2xl font-semibold mb-3 text-ink">{s.heading}</h3>
            {s.type === 'table' ? (
              <div className="overflow-x-auto rounded-2xl border border-ink/10">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-pistachio/40">
                      {s.headers.map((h, j) => (
                        <th key={j} className="px-4 py-3 text-left font-display text-ink">{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {s.rows.map((row, ri) => (
                      <tr key={ri} className="border-t border-ink/10">
                        {row.map((cell, ci) => (
                          <td key={ci} className="px-4 py-3 text-ink/80">{cell}</td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p className="text-lg leading-relaxed text-ink/80 whitespace-pre-line">{s.body}</p>
            )}
          </motion.section>
        ))}
      </div>

      {chapter.keyTerms?.length > 0 && (
        <div className="mt-14 p-6 bg-pistachio/30 rounded-3xl">
          <p className="font-display uppercase text-xs tracking-[0.2em] text-ink/60 mb-4">Key Terms</p>
          <div className="grid gap-4 md:grid-cols-2">
            {chapter.keyTerms.map((k) => (
              <div key={k.term}>
                <p className="font-display font-semibold text-ink">{k.term}</p>
                <p className="text-ink/70 text-sm">{k.definition}</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </motion.article>
  );
}
JSXEOF

# ChatPanel — apply content font to messages + show API errors inline
cat > client/src/components/ChatPanel.jsx <<'JSXEOF'
import { useState, useRef, useEffect } from 'react';
import { motion } from 'framer-motion';
import { api } from '../api/client';
import { useLang } from '../contexts/LangContext';
import MagneticButton from './MagneticButton';

export default function ChatPanel({ chapter }) {
  const { lang } = useLang();
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const scrollRef = useRef(null);

  useEffect(() => {
    setMessages(chapter ? [{
      role: 'assistant',
      content: `I've read "${chapter.title}". Ask me anything — follow-ups, examples, a quiz, or a simpler explanation.`,
    }] : []);
  }, [chapter]);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' });
  }, [messages, loading]);

  const send = async (e) => {
    e?.preventDefault();
    if (!input.trim() || loading || !chapter) return;
    const next = [...messages, { role: 'user', content: input }];
    setMessages(next);
    setInput('');
    setLoading(true);
    try {
      const context = chapter.sections
        .filter(s => s.body)
        .map(s => `${s.heading}: ${s.body}`)
        .join('\n\n');
      const { data } = await api.chat({ messages: next, context, language: lang });
      setMessages([...next, { role: 'assistant', content: data.reply }]);
    } catch (err) {
      setMessages([...next, {
        role: 'assistant',
        content: `⚠ ${err.response?.data?.detail || err.message}`,
      }]);
    } finally { setLoading(false); }
  };

  return (
    <div className="flex flex-col h-full bg-surface border-l border-ink/10">
      <div className="px-4 py-3 border-b border-ink/10">
        <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry">AI Tutor</p>
        <p className="text-xs text-ink/50 mt-0.5">
          {chapter ? `Studying: ${chapter.title}` : 'Load a chapter to begin'}
        </p>
      </div>

      <div ref={scrollRef} data-lenis-prevent className="flex-1 overflow-y-auto px-4 py-4 space-y-3">
        {messages.map((m, i) => (
          <motion.div key={i}
            initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}
            className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div
              className={`max-w-[85%] px-4 py-2.5 rounded-2xl text-sm leading-relaxed whitespace-pre-line ${
                m.role === 'user' ? 'bg-raspberry text-white' : 'bg-ink/5 text-ink'
              } ${m.role === 'assistant' ? `content-${lang}` : ''}`}
            >
              {m.content}
            </div>
          </motion.div>
        ))}
        {loading && (
          <div className="flex gap-1.5 px-4 py-3 bg-ink/5 rounded-2xl w-fit">
            {[0, 1, 2].map(i => (
              <motion.div key={i}
                animate={{ opacity: [0.3, 1, 0.3] }}
                transition={{ duration: 1.2, repeat: Infinity, delay: i * 0.2 }}
                className="w-1.5 h-1.5 rounded-full bg-ink/40" />
            ))}
          </div>
        )}
      </div>

      <form onSubmit={send} className="p-3 border-t border-ink/10">
        <div className="flex gap-2">
          <input
            value={input}
            onChange={e => setInput(e.target.value)}
            placeholder={chapter ? 'Ask a follow-up…' : 'Load a chapter first'}
            disabled={!chapter || loading}
            className={`flex-1 px-3 py-2 text-sm bg-ink/5 rounded-xl outline-none focus:ring-2 focus:ring-raspberry text-ink placeholder:text-ink/30 disabled:opacity-50 content-${lang}`}
          />
          <MagneticButton type="submit" disabled={loading || !input.trim() || !chapter}
            className="px-4 py-2 bg-raspberry text-white text-sm rounded-xl disabled:opacity-40">
            Send
          </MagneticButton>
        </div>
      </form>
    </div>
  );
}
JSXEOF

# Sidebar — swap any remaining bg-white for surface; keep look
cat > client/src/components/Sidebar.jsx <<'JSXEOF'
import { useTheme } from '../contexts/ThemeContext';
import { useLang } from '../contexts/LangContext';
import { LANGUAGES } from '../constants/languages';

export default function Sidebar({ topics, currentSlug, onSelect, onNew }) {
  const { theme, toggle } = useTheme();
  const { lang, setLang } = useLang();

  return (
    <aside className="w-72 h-full flex flex-col bg-surface border-r border-ink/10 p-4 shrink-0">
      <h1 className="font-body text-2xl mb-6">
        SDG4 <span className="text-raspberry">Study</span>
      </h1>

      <button onClick={onNew}
        className="mb-5 w-full px-4 py-2 bg-raspberry text-white text-sm font-display rounded-xl hover:opacity-90">
        + New Topic
      </button>

      <div data-lenis-prevent className="flex-1 overflow-y-auto">
        <p className="font-display uppercase text-xs tracking-wider text-ink/40 mb-2">Sources</p>
        <div className="space-y-1">
          {topics.map(t => (
            <button key={t.slug} onClick={() => onSelect(t.slug)}
              className={`w-full text-left px-3 py-2 rounded-lg transition-colors ${
                currentSlug === t.slug ? 'bg-pistachio/40 text-ink' : 'text-ink/70 hover:bg-ink/5'
              }`}>
              <p className="font-body text-sm">{t.title}</p>
              <p className="text-[10px] uppercase tracking-wider text-ink/40 mt-0.5">{t.subject}</p>
            </button>
          ))}
        </div>
      </div>

      <div className="mt-4 space-y-3">
        <div>
          <p className="font-display uppercase text-xs tracking-wider text-ink/40 mb-1.5">Language</p>
          <select value={lang} onChange={e => setLang(e.target.value)}
            className="w-full px-3 py-2 bg-ink/5 rounded-lg text-sm text-ink outline-none cursor-pointer">
            {LANGUAGES.map(l => <option key={l.code} value={l.code}>{l.name}</option>)}
          </select>
        </div>
        <button onClick={toggle}
          className="w-full px-3 py-2 bg-ink/5 hover:bg-ink/10 rounded-lg text-sm text-ink font-display">
          {theme === 'dark' ? '☀ Light Mode' : '☾ Dark Mode'}
        </button>
      </div>
    </aside>
  );
}
JSXEOF

echo ""
echo "✅ All fixes applied:"
echo "  • Backend chat/translate now use direct REST (no SDK, fixes 500)"
echo "  • Chat errors surface inline instead of 500"
echo "  • Per-language font classes drive typography on switch"
echo "  • Kia Seltos HTX palette: warm cream + charcoal + bronze + raspberry"
echo "  • Dark theme FOUC fix via inline <script> in index.html"
echo ""
echo "Restart both servers:"
echo "  Terminal 1: cd server-python && .venv\\Scripts\\activate && uvicorn app.main:app --reload --port 8000"
echo "  Terminal 2: cd server-node && npm start"
echo "  Terminal 3: cd client && npm run dev"