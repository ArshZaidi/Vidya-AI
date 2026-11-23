#!/usr/bin/env bash
set -euo pipefail

mkdir -p client/src/contexts client/src/constants client/src/components

# --- index.html with Noto fonts for every script ---
cat > client/index.html <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
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
EOF

# --- tailwind config with CSS vars ---
cat > client/tailwind.config.js <<'EOF'
export default {
  darkMode: 'class',
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: {
        pistachio: 'rgb(var(--pistachio-rgb) / <alpha-value>)',
        ink: 'rgb(var(--ink-rgb) / <alpha-value>)',
        raspberry: 'rgb(var(--raspberry-rgb) / <alpha-value>)',
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
EOF

# --- index.css with dark mode vars ---
cat > client/src/index.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --ink-rgb: 20 20 20;
  --bg-rgb: 250 250 247;
  --pistachio-rgb: 189 218 159;
  --raspberry-rgb: 233 20 94;
  --surface-rgb: 255 255 255;
}

.dark {
  --ink-rgb: 245 245 240;
  --bg-rgb: 15 15 15;
  --pistachio-rgb: 163 196 136;
  --raspberry-rgb: 255 61 127;
  --surface-rgb: 28 28 28;
}

html, body, #root { height: 100%; margin: 0; }

body {
  background: rgb(var(--bg-rgb));
  color: rgb(var(--ink-rgb));
  font-family: 'DM Serif Display', serif;
  -webkit-font-smoothing: antialiased;
}

html.lenis, html.lenis body { height: auto; }
.lenis.lenis-smooth { scroll-behavior: auto !important; }

::selection { background: rgb(var(--raspberry-rgb)); color: white; }

::-webkit-scrollbar { width: 8px; height: 8px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: rgb(var(--ink-rgb) / 0.15); border-radius: 4px; }
::-webkit-scrollbar-thumb:hover { background: rgb(var(--raspberry-rgb)); }
EOF

# --- Language constants ---
cat > client/src/constants/languages.js <<'EOF'
export const LANGUAGES = [
  { code: 'en', label: 'EN',   name: 'English',    font: "'DM Serif Display', serif" },
  { code: 'hi', label: 'हिं',  name: 'हिन्दी',     font: "'Noto Sans Devanagari', sans-serif" },
  { code: 'bn', label: 'বাং',  name: 'বাংলা',      font: "'Noto Sans Bengali', sans-serif" },
  { code: 'mr', label: 'मरा',  name: 'मराठी',      font: "'Noto Sans Devanagari', sans-serif" },
  { code: 'ta', label: 'த',    name: 'தமிழ்',     font: "'Noto Sans Tamil', sans-serif" },
  { code: 'te', label: 'తె',   name: 'తెలుగు',     font: "'Noto Sans Telugu', sans-serif" },
  { code: 'kn', label: 'ಕ',    name: 'ಕನ್ನಡ',     font: "'Noto Sans Kannada', sans-serif" },
  { code: 'ml', label: 'മ',    name: 'മലയാളം',    font: "'Noto Sans Malayalam', sans-serif" },
  { code: 'gu', label: 'ગુ',   name: 'ગુજરાતી',   font: "'Noto Sans Gujarati', sans-serif" },
  { code: 'pa', label: 'ਪੰ',   name: 'ਪੰਜਾਬੀ',     font: "'Noto Sans Gurmukhi', sans-serif" },
  { code: 'ur', label: 'اردو', name: 'اُردُو',     font: "'Noto Nastaliq Urdu', serif" },
  { code: 'or', label: 'ଓ',    name: 'ଓଡ଼ିଆ',      font: "'Noto Sans Oriya', sans-serif" },
];

export const getLang = (code) =>
  LANGUAGES.find((l) => l.code === code) || LANGUAGES[0];
EOF

# --- Theme provider ---
cat > client/src/contexts/ThemeContext.jsx <<'EOF'
import { createContext, useContext, useEffect, useState } from 'react';

const ThemeContext = createContext();
export const useTheme = () => useContext(ThemeContext);

export function ThemeProvider({ children }) {
  const [theme, setTheme] = useState(
    () => localStorage.getItem('sdg4-theme') || 'light'
  );
  useEffect(() => {
    document.documentElement.classList.toggle('dark', theme === 'dark');
    localStorage.setItem('sdg4-theme', theme);
  }, [theme]);
  return (
    <ThemeContext.Provider
      value={{
        theme,
        toggle: () => setTheme((t) => (t === 'dark' ? 'light' : 'dark')),
      }}
    >
      {children}
    </ThemeContext.Provider>
  );
}
EOF

# --- Language provider ---
cat > client/src/contexts/LangContext.jsx <<'EOF'
import { createContext, useContext, useState } from 'react';

const LangContext = createContext();
export const useLang = () => useContext(LangContext);

export function LangProvider({ children }) {
  const [lang, setLang] = useState('en');
  return (
    <LangContext.Provider value={{ lang, setLang }}>
      {children}
    </LangContext.Provider>
  );
}
EOF

# --- API client with chat + grade ---
cat > client/src/api/client.js <<'EOF'
import axios from "axios";

const node = axios.create({ baseURL: "/api", timeout: 20000 });
const ai   = axios.create({ baseURL: "/ai",  timeout: 60000 });

export const api = {
  health:        () => node.get("/health"),
  topics:        () => node.get("/topics"),
  search:        (q) => node.get("/search", { params: { q } }),
  chapter:       (slug) => node.get(`/topic/${slug}`),
  exercises:     (topic) => node.get("/exercises", { params: { topic } }),
  certifications:(topic) => node.get("/certifications", { params: { topic } }),
  resources:     (topic) => node.get("/resources", { params: { topic } }),
  leaderboard:   () => node.get("/leaderboard"),
  translate:     (text, target_language) =>
    ai.post("/translate", { text, target_language, source_language: "en" }),
  chat:          (payload) => ai.post("/chat", payload),
  grade:         (payload) => ai.post("/grade", payload),
};
EOF

# --- YouTube embed ---
cat > client/src/components/YouTubeEmbed.jsx <<'EOF'
export default function YouTubeEmbed({ videoId, title }) {
  if (!videoId) return null;
  return (
    <div className="rounded-2xl overflow-hidden bg-black aspect-video shadow-xl">
      <iframe
        className="w-full h-full"
        src={`https://www.youtube.com/embed/${videoId}?cc_load_policy=1&rel=0`}
        title={title || 'Video lesson'}
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
        allowFullScreen
      />
    </div>
  );
}
EOF

# --- VideoPlayer using YouTube ---
cat > client/src/components/VideoPlayer.jsx <<'EOF'
import YouTubeEmbed from './YouTubeEmbed';

export default function VideoPlayer({ chapter }) {
  if (!chapter) return null;
  const hasYt = !!chapter.youtubeId;
  const hasMp4 = !!chapter.videoUrl;
  if (!hasYt && !hasMp4) return null;

  return (
    <div className="mt-12">
      <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry mb-3">
        Video Lesson · Subtitled
      </p>
      {hasYt ? (
        <YouTubeEmbed videoId={chapter.youtubeId} title={chapter.title} />
      ) : (
        <video controls className="w-full aspect-video rounded-2xl bg-black">
          <source src={chapter.videoUrl} />
          <track kind="captions" src={chapter.subtitlesUrl} srcLang="en" label="English" default />
        </video>
      )}
      <p className="text-xs text-ink/40 mt-2 text-center">
        Turn on CC (captions) for deaf-student accessibility
      </p>
    </div>
  );
}
EOF

# --- Chat panel ---
cat > client/src/components/ChatPanel.jsx <<'EOF'
import { useState, useRef, useEffect } from 'react';
import { motion } from 'framer-motion';
import { api } from '../api/client';
import { useLang } from '../contexts/LangContext';
import { getLang } from '../constants/languages';
import MagneticButton from './MagneticButton';

export default function ChatPanel({ chapter }) {
  const { lang } = useLang();
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const scrollRef = useRef(null);
  const langMeta = getLang(lang);

  useEffect(() => {
    if (chapter) {
      setMessages([
        {
          role: 'assistant',
          content: `I've read "${chapter.title}". Ask me anything — a follow-up, an example, a simpler explanation, or a quiz.`,
        },
      ]);
    } else {
      setMessages([]);
    }
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
        .filter((s) => s.body)
        .map((s) => `${s.heading}: ${s.body}`)
        .join('\n\n');
      const { data } = await api.chat({
        messages: next,
        context,
        language: lang,
      });
      setMessages([...next, { role: 'assistant', content: data.reply }]);
    } catch (err) {
      setMessages([
        ...next,
        {
          role: 'assistant',
          content: `⚠ ${err.response?.data?.detail || err.message}. Add GEMINI_API_KEY in server-python/.env and restart FastAPI.`,
        },
      ]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col h-full bg-surface border-l border-ink/10">
      <div className="px-4 py-3 border-b border-ink/10">
        <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry">AI Tutor</p>
        <p className="text-xs text-ink/50 mt-0.5">
          {chapter ? `Studying: ${chapter.title}` : 'Load a chapter to begin'}
        </p>
      </div>

      <div ref={scrollRef} className="flex-1 overflow-y-auto px-4 py-4 space-y-3">
        {messages.map((m, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}
          >
            <div
              className={`max-w-[85%] px-4 py-2.5 rounded-2xl text-sm leading-relaxed whitespace-pre-line ${
                m.role === 'user'
                  ? 'bg-raspberry text-white'
                  : 'bg-ink/5 text-ink'
              }`}
              style={m.role === 'assistant' ? { fontFamily: langMeta.font } : {}}
            >
              {m.content}
            </div>
          </motion.div>
        ))}
        {loading && (
          <div className="flex gap-1.5 px-4 py-3 bg-ink/5 rounded-2xl w-fit">
            {[0, 1, 2].map((i) => (
              <motion.div
                key={i}
                animate={{ opacity: [0.3, 1, 0.3] }}
                transition={{ duration: 1.2, repeat: Infinity, delay: i * 0.2 }}
                className="w-1.5 h-1.5 rounded-full bg-ink/40"
              />
            ))}
          </div>
        )}
      </div>

      <form onSubmit={send} className="p-3 border-t border-ink/10">
        <div className="flex gap-2">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder={chapter ? 'Ask a follow-up…' : 'Load a chapter first'}
            disabled={!chapter || loading}
            className="flex-1 px-3 py-2 text-sm bg-ink/5 rounded-xl outline-none focus:ring-2 focus:ring-raspberry text-ink placeholder:text-ink/30 disabled:opacity-50"
            style={{ fontFamily: langMeta.font }}
          />
          <MagneticButton
            type="submit"
            disabled={loading || !input.trim() || !chapter}
            className="px-4 py-2 bg-raspberry text-white text-sm rounded-xl disabled:opacity-40"
          >
            Send
          </MagneticButton>
        </div>
      </form>
    </div>
  );
}
EOF

# --- Sidebar ---
cat > client/src/components/Sidebar.jsx <<'EOF'
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

      <button
        onClick={onNew}
        className="mb-5 w-full px-4 py-2 bg-raspberry text-white text-sm font-display rounded-xl hover:opacity-90 transition-opacity"
      >
        + New Topic
      </button>

      <div className="flex-1 overflow-y-auto">
        <p className="font-display uppercase text-xs tracking-wider text-ink/40 mb-2">Sources</p>
        <div className="space-y-1">
          {topics.map((t) => (
            <button
              key={t.slug}
              onClick={() => onSelect(t.slug)}
              className={`w-full text-left px-3 py-2 rounded-lg transition-colors ${
                currentSlug === t.slug
                  ? 'bg-pistachio/40 text-ink'
                  : 'text-ink/70 hover:bg-ink/5'
              }`}
            >
              <p className="font-body text-sm">{t.title}</p>
              <p className="text-[10px] uppercase tracking-wider text-ink/40 mt-0.5">{t.subject}</p>
            </button>
          ))}
        </div>
      </div>

      <div className="mt-4 space-y-3">
        <div>
          <p className="font-display uppercase text-xs tracking-wider text-ink/40 mb-1.5">Language</p>
          <select
            value={lang}
            onChange={(e) => setLang(e.target.value)}
            className="w-full px-3 py-2 bg-ink/5 rounded-lg text-sm text-ink outline-none cursor-pointer"
          >
            {LANGUAGES.map((l) => (
              <option key={l.code} value={l.code}>
                {l.name}
              </option>
            ))}
          </select>
        </div>
        <button
          onClick={toggle}
          className="w-full px-3 py-2 bg-ink/5 hover:bg-ink/10 rounded-lg text-sm text-ink font-display transition-colors"
        >
          {theme === 'dark' ? '☀ Light Mode' : '☾ Dark Mode'}
        </button>
      </div>
    </aside>
  );
}
EOF

# --- LanguageToggle (pills) ---
cat > client/src/components/LanguageToggle.jsx <<'EOF'
import { motion } from 'framer-motion';
import { LANGUAGES } from '../constants/languages';

export default function LanguageToggle({ value, onChange }) {
  return (
    <div className="inline-flex p-1 bg-ink/5 rounded-full overflow-x-auto max-w-full no-scrollbar">
      {LANGUAGES.map((l) => {
        const active = value === l.code;
        return (
          <button
            key={l.code}
            onClick={() => onChange(l.code)}
            className="relative px-3 py-1.5 text-sm whitespace-nowrap rounded-full font-display"
            style={{ fontFamily: l.font }}
          >
            {active && (
              <motion.span
                layoutId="lang-pill"
                className="absolute inset-0 bg-raspberry rounded-full"
                transition={{ type: 'spring', stiffness: 400, damping: 30 }}
              />
            )}
            <span className={`relative z-10 ${active ? 'text-white' : 'text-ink/60'}`}>
              {l.label}
            </span>
          </button>
        );
      })}
    </div>
  );
}
EOF

# --- ChapterViewer with fonts + tables ---
cat > client/src/components/ChapterViewer.jsx <<'EOF'
import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { api } from '../api/client';
import { useLang } from '../contexts/LangContext';
import { getLang } from '../constants/languages';
import LanguageToggle from './LanguageToggle';
import MagneticButton from './MagneticButton';

export default function ChapterViewer({ chapter }) {
  const { lang, setLang } = useLang();
  const [sections, setSections] = useState(chapter.sections);
  const [translating, setTranslating] = useState(false);
  const [speaking, setSpeaking] = useState(false);
  const langMeta = getLang(lang);

  useEffect(() => {
    setSections(chapter.sections);
  }, [chapter]);

  const translateAll = async (target) => {
    setLang(target);
    if (target === 'en') {
      setSections(chapter.sections);
      return;
    }
    setTranslating(true);
    try {
      const translated = await Promise.all(
        chapter.sections.map(async (s) => {
          if (s.type === 'table') {
            const headers = await Promise.all(
              s.headers.map((h) => api.translate(h, target).then((r) => r.data.translated_text))
            );
            const rows = await Promise.all(
              s.rows.map((row) =>
                Promise.all(row.map((cell) =>
                  api.translate(cell, target).then((r) => r.data.translated_text)
                ))
              )
            );
            const heading = (await api.translate(s.heading, target)).data.translated_text;
            return { ...s, heading, headers, rows };
          }
          const [h, b] = await Promise.all([
            api.translate(s.heading, target),
            api.translate(s.body || '', target),
          ]);
          return { ...s, heading: h.data.translated_text, body: b.data.translated_text };
        })
      );
      setSections(translated);
    } catch {
      setSections(chapter.sections);
    } finally {
      setTranslating(false);
    }
  };

  const speak = () => {
    if (!('speechSynthesis' in window)) return;
    if (speaking) {
      window.speechSynthesis.cancel();
      setSpeaking(false);
      return;
    }
    const text = sections
      .map((s) => {
        if (s.type === 'table') return s.heading;
        return `${s.heading}. ${s.body || ''}`;
      })
      .join('. ');
    const u = new SpeechSynthesisUtterance(text);
    u.lang = lang === 'hi' || lang === 'mr' ? 'hi-IN'
      : lang === 'ta' ? 'ta-IN'
      : lang === 'te' ? 'te-IN'
      : lang === 'bn' ? 'bn-IN'
      : lang === 'kn' ? 'kn-IN'
      : lang === 'ml' ? 'ml-IN'
      : lang === 'gu' ? 'gu-IN'
      : lang === 'pa' ? 'pa-IN'
      : lang === 'ur' ? 'ur-IN'
      : 'en-US';
    u.onend = () => setSpeaking(false);
    window.speechSynthesis.speak(u);
    setSpeaking(true);
  };

  const downloadNotes = () => {
    const md = `# ${chapter.title}\n\n${sections
      .map((s) => {
        if (s.type === 'table') {
          const head = `| ${s.headers.join(' | ')} |\n| ${s.headers.map(() => '---').join(' | ')} |`;
          const body = s.rows.map((r) => `| ${r.join(' | ')} |`).join('\n');
          return `## ${s.heading}\n\n${head}\n${body}`;
        }
        return `## ${s.heading}\n\n${s.body}`;
      })
      .join('\n\n')}`;
    const blob = new Blob([md], { type: 'text/markdown' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${chapter.slug}-notes.md`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <motion.article
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
    >
      <div className="flex flex-wrap items-end justify-between gap-4 mb-6">
        <div>
          <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry">
            {chapter.subject} · {chapter.readingTimeMinutes} min read
          </p>
          <h2
            className="font-body text-5xl md:text-6xl mt-2 leading-[0.95]"
            style={{ fontFamily: langMeta.font }}
          >
            {chapter.title}
          </h2>
        </div>
        <LanguageToggle value={lang} onChange={translateAll} />
      </div>

      <div className="flex flex-wrap gap-3 mb-10">
        <MagneticButton
          onClick={speak}
          className="px-6 py-2.5 bg-ink text-pistachio rounded-full font-display text-sm tracking-wider"
        >
          {speaking ? '◼ Stop' : '▶ Listen'}
        </MagneticButton>
        <MagneticButton
          onClick={downloadNotes}
          className="px-6 py-2.5 bg-pistachio text-ink rounded-full font-display text-sm tracking-wider"
        >
          ↓ Download Notes
        </MagneticButton>
      </div>

      <div className={`space-y-10 ${translating ? 'opacity-50 transition-opacity' : ''}`}>
        {sections.map((s, i) => (
          <motion.section
            key={i}
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.5, delay: i * 0.04 }}
          >
            <h3
              className="font-display text-2xl font-semibold mb-3 text-ink"
              style={{ fontFamily: langMeta.font }}
            >
              {s.heading}
            </h3>
            {s.type === 'table' ? (
              <div className="overflow-x-auto rounded-2xl border border-ink/10">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-pistachio/30">
                      {s.headers.map((h, j) => (
                        <th
                          key={j}
                          className="px-4 py-3 text-left font-display text-ink"
                          style={{ fontFamily: langMeta.font }}
                        >
                          {h}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {s.rows.map((row, ri) => (
                      <tr key={ri} className="border-t border-ink/10">
                        {row.map((cell, ci) => (
                          <td
                            key={ci}
                            className="px-4 py-3 font-body text-ink/80"
                            style={{ fontFamily: langMeta.font }}
                          >
                            {cell}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p
                className="font-body text-lg leading-relaxed text-ink/80 whitespace-pre-line"
                style={{ fontFamily: langMeta.font }}
              >
                {s.body}
              </p>
            )}
          </motion.section>
        ))}
      </div>

      {chapter.keyTerms?.length > 0 && (
        <div className="mt-14 p-6 bg-pistachio/30 rounded-3xl">
          <p className="font-display uppercase text-xs tracking-[0.2em] text-ink/60 mb-4">
            Key Terms
          </p>
          <div className="grid gap-4 md:grid-cols-2">
            {chapter.keyTerms.map((k) => (
              <div key={k.term}>
                <p className="font-display font-semibold" style={{ fontFamily: langMeta.font }}>
                  {k.term}
                </p>
                <p className="font-body text-ink/70 text-sm" style={{ fontFamily: langMeta.font }}>
                  {k.definition}
                </p>
              </div>
            ))}
          </div>
        </div>
      )}
    </motion.article>
  );
}
EOF

# --- ExerciseCard with AI grading ---
cat > client/src/components/ExerciseCard.jsx <<'EOF'
import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { api } from '../api/client';
import MagneticButton from './MagneticButton';

export default function ExerciseCard({ exercises, onComplete }) {
  const list = Array.isArray(exercises) ? exercises : [];
  const [answers, setAnswers] = useState({});
  const [results, setResults] = useState({});
  const [grading, setGrading] = useState({});

  if (!list.length) return null;

  const submit = async (ex) => {
    const userAnswer = (answers[ex.id] || '').trim();
    if (!userAnswer) return;
    setGrading((g) => ({ ...g, [ex.id]: true }));

    try {
      const { data } = await api.grade({
        question: ex.question,
        user_answer: userAnswer,
        model_answer: ex.answer || ex.modelAnswer || '',
      });
      setResults((r) => ({ ...r, [ex.id]: data }));
      if (data.correct) onComplete?.(ex.id);
    } catch {
      const correct = ex.type === 'multiple-choice'
        ? userAnswer === ex.answer
        : userAnswer.length > 3;
      setResults((r) => ({ ...r, [ex.id]: { correct, feedback: '' } }));
      if (correct) onComplete?.(ex.id);
    } finally {
      setGrading((g) => ({ ...g, [ex.id]: false }));
    }
  };

  return (
    <div className="mt-16">
      <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry mb-3">
        Practical Exercise
      </p>
      <div className="space-y-6">
        {list.map((ex) => {
          const done = ex.id in results;
          const isCorrect = done && results[ex.id].correct;
          const isGrading = grading[ex.id];
          return (
            <motion.div
              key={ex.id}
              initial={{ opacity: 0, y: 16 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              className="p-8 bg-surface rounded-3xl border border-ink/10 shadow-sm"
            >
              <p className="font-body text-xl mb-6 text-ink">{ex.question}</p>

              {ex.type === 'multiple-choice' && (
                <div className="grid gap-3 md:grid-cols-2 mb-6">
                  {ex.options.map((opt) => (
                    <button
                      key={opt}
                      onClick={() => setAnswers((a) => ({ ...a, [ex.id]: opt }))}
                      disabled={done || isGrading}
                      className={`text-left px-5 py-3 rounded-2xl border-2 transition-all font-body ${
                        answers[ex.id] === opt
                          ? 'border-raspberry bg-raspberry/10 text-ink'
                          : 'border-ink/10 text-ink hover:border-ink/30'
                      } disabled:opacity-60`}
                    >
                      {opt}
                    </button>
                  ))}
                </div>
              )}

              {ex.type === 'coding' && (
                <textarea
                  value={answers[ex.id] || ''}
                  onChange={(e) => setAnswers((a) => ({ ...a, [ex.id]: e.target.value }))}
                  disabled={done || isGrading}
                  rows={5}
                  className="w-full p-4 font-mono text-sm bg-ink/5 rounded-2xl outline-none focus:ring-2 focus:ring-raspberry text-ink"
                  placeholder="Write your answer…"
                />
              )}

              <div className="mt-6 flex flex-wrap items-center gap-4">
                <MagneticButton
                  onClick={() => submit(ex)}
                  disabled={done || isGrading || !answers[ex.id]}
                  className="px-6 py-2.5 bg-ink text-pistachio rounded-full font-display text-sm tracking-wider disabled:opacity-40"
                >
                  {isGrading ? 'Grading…' : done ? (isCorrect ? 'Correct ✓' : 'Incorrect ✗') : 'Check Answer'}
                </MagneticButton>
                <AnimatePresence>
                  {done && (
                    <motion.span
                      initial={{ opacity: 0, x: -8 }}
                      animate={{ opacity: 1, x: 0 }}
                      className={`font-display text-sm ${isCorrect ? 'text-green-500' : 'text-raspberry'}`}
                    >
                      {isCorrect ? '+50 XP · +10 credits' : 'Try again'}
                    </motion.span>
                  )}
                </AnimatePresence>
              </div>

              {done && results[ex.id].feedback && (
                <motion.p
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  className="mt-4 text-sm text-ink/60 italic"
                >
                  {results[ex.id].feedback}
                </motion.p>
              )}
              {done && !results[ex.id].feedback && isCorrect && ex.explanation && (
                <motion.p
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  className="mt-4 text-sm text-ink/60 italic"
                >
                  {ex.explanation}
                </motion.p>
              )}
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}
EOF

# --- ResourcesList unchanged ---
cat > client/src/components/ResourcesList.jsx <<'EOF'
export default function ResourcesList({ certifications, resources }) {
  const certList = Object.values(certifications || {}).flat();
  const resList = Object.values(resources || {}).flat();
  if (!certList.length && !resList.length) return null;
  return (
    <div className="mt-16 grid gap-8 md:grid-cols-2">
      <div>
        <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry mb-3">
          Certifications
        </p>
        <ul className="space-y-2">
          {certList.map((c) => (
            <li key={c.title}>
              <a href={c.url} target="_blank" rel="noreferrer"
                className="block p-4 rounded-2xl bg-surface border border-ink/10 hover:border-raspberry transition-colors">
                <p className="font-body text-lg text-ink">{c.title}</p>
                <p className="text-xs text-ink/40 mt-1 truncate">{c.url}</p>
              </a>
            </li>
          ))}
        </ul>
      </div>
      <div>
        <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry mb-3">
          Trusted Resources
        </p>
        <ul className="space-y-2">
          {resList.map((r) => (
            <li key={r.title}>
              <a href={r.url} target="_blank" rel="noreferrer"
                className="block p-4 rounded-2xl bg-surface border border-ink/10 hover:border-raspberry transition-colors">
                <p className="font-body text-lg text-ink">{r.title}</p>
                <p className="text-xs text-ink/40 mt-1">{r.type}</p>
              </a>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
EOF

# --- TopicSearch (landing state) ---
cat > client/src/components/TopicSearch.jsx <<'EOF'
import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { api } from '../api/client';
import MagneticButton from './MagneticButton';

const SUGGESTIONS = ['photosynthesis', 'newtons-laws', 'python-basics'];

export default function TopicSearch({ onLoad }) {
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const submit = async (e) => {
    e?.preventDefault();
    if (!query.trim()) return;
    setLoading(true);
    setError('');
    try {
      const { data } = await api.search(query.trim());
      onLoad(data);
    } catch (err) {
      setError(err.response?.data?.error || 'Could not load topic');
    } finally {
      setLoading(false);
    }
  };

  return (
    <motion.section
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="w-full max-w-2xl"
    >
      <form onSubmit={submit} className="relative">
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="What do you want to study today?"
          className="w-full px-7 py-5 text-lg font-body bg-surface border-2 border-ink/10 rounded-full text-ink placeholder:text-ink/30 outline-none focus:border-raspberry transition-colors shadow-sm"
        />
        <MagneticButton
          type="submit"
          disabled={loading}
          className="absolute right-2 top-1/2 -translate-y-1/2 px-6 py-3 bg-raspberry text-white font-display font-semibold rounded-full tracking-wide hover:opacity-90 disabled:opacity-60"
        >
          {loading ? '…' : 'Begin'}
        </MagneticButton>
      </form>
      <div className="mt-5 flex flex-wrap gap-2 justify-center">
        {SUGGESTIONS.map((s) => (
          <button key={s} onClick={() => setQuery(s)}
            className="px-4 py-1.5 text-sm font-display uppercase tracking-wider text-ink/60 border border-ink/15 rounded-full hover:bg-pistachio/60 hover:text-ink transition-colors">
            {s.replace('-', ' ')}
          </button>
        ))}
      </div>
      <AnimatePresence>
        {error && (
          <motion.p initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            className="mt-4 text-center text-sm text-raspberry">{error}</motion.p>
        )}
      </AnimatePresence>
    </motion.section>
  );
}
EOF

# --- GamificationBar (compact, top-right of chat area) ---
cat > client/src/components/GamificationBar.jsx <<'EOF'
export default function GamificationBar({ xp, credits, rank, streak }) {
  return (
    <div className="flex items-center gap-5 text-xs font-display tracking-wide">
      <span className="text-ink/50">Rank <span className="text-ink font-semibold">{rank}</span></span>
      <span className="text-ink/50">XP <span className="text-raspberry font-semibold">{xp}</span></span>
      <span className="text-ink/50">Credits <span className="text-ink font-semibold">{credits}</span></span>
      {streak > 0 && <span>🔥 {streak}</span>}
    </div>
  );
}
EOF

# --- App.jsx — NotebookLM layout ---
cat > client/src/App.jsx <<'EOF'
import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { api } from './api/client';
import { useGamification } from './hooks/useGamification';
import { useSmoothScroll } from './hooks/useSmoothScroll';
import Sidebar from './components/Sidebar';
import ChapterViewer from './components/ChapterViewer';
import VideoPlayer from './components/VideoPlayer';
import ExerciseCard from './components/ExerciseCard';
import ChatPanel from './components/ChatPanel';
import ResourcesList from './components/ResourcesList';
import TopicSearch from './components/TopicSearch';
import GamificationBar from './components/GamificationBar';

export default function App() {
  useSmoothScroll();
  const { xp, credits, rank, streak, awardForExercise } = useGamification();
  const [topics, setTopics] = useState([]);
  const [chapter, setChapter] = useState(null);
  const [exercises, setExercises] = useState([]);
  const [certs, setCerts] = useState({});
  const [resources, setResources] = useState({});

  useEffect(() => {
    api.topics().then(({ data }) => setTopics(data.topics)).catch(() => {});
  }, []);

  const loadExtras = async (slug) => {
    const [ex, ce, re] = await Promise.all([
      api.exercises(slug),
      api.certifications(slug),
      api.resources(slug),
    ]);
    setExercises(ex.data.exercises[slug] || []);
    setCerts(ce.data.certifications);
    setResources(re.data.resources);
  };

  const loadChapter = (data) => {
    setChapter(data);
    loadExtras(data.slug);
  };

  const loadBySlug = async (slug) => {
    const { data } = await api.chapter(slug);
    loadChapter(data);
  };

  return (
    <div className="flex h-screen overflow-hidden bg-bg text-ink">
      <Sidebar
        topics={topics}
        currentSlug={chapter?.slug}
        onSelect={loadBySlug}
        onNew={() => { setChapter(null); setExercises([]); setCerts({}); setResources({}); }}
      />

      <main className="flex-1 overflow-y-auto">
        <div className="sticky top-0 z-10 bg-bg/80 backdrop-blur-md border-b border-ink/5 px-8 py-3 flex items-center justify-between">
          <p className="font-display uppercase text-xs tracking-[0.2em] text-ink/40">
            {chapter ? 'Reading' : 'Start'}
          </p>
          <GamificationBar xp={xp} credits={credits} rank={rank} streak={streak} />
        </div>

        <div className="px-8 py-8 max-w-3xl mx-auto">
          <AnimatePresence mode="wait">
            {!chapter ? (
              <motion.div
                key="landing"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="flex flex-col items-center justify-center min-h-[70vh]"
              >
                <motion.h1
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.1 }}
                  className="font-body text-5xl md:text-7xl text-center leading-[0.95] mb-4"
                >
                  Learn <em className="text-raspberry">anything</em>,<br />
                  in your <span className="text-ink/40">way.</span>
                </motion.h1>
                <p className="font-display uppercase text-xs tracking-[0.25em] text-ink/40 mb-12">
                  SDG 4 · Quality Education For All
                </p>
                <TopicSearch onLoad={loadChapter} />
              </motion.div>
            ) : (
              <motion.div key="chapter" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
                <button
                  onClick={() => { setChapter(null); setExercises([]); setCerts({}); setResources({}); }}
                  className="mb-4 text-sm font-display uppercase tracking-wider text-ink/40 hover:text-raspberry transition-colors"
                >
                  ← New topic
                </button>
                <ChapterViewer chapter={chapter} />
                <VideoPlayer chapter={chapter} />
                <ExerciseCard exercises={exercises} onComplete={awardForExercise} />
                <ResourcesList certifications={certs} resources={resources} />
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </main>

      {chapter && (
        <div className="w-[380px] shrink-0 hidden lg:block">
          <ChatPanel chapter={chapter} />
        </div>
      )}
    </div>
  );
}
EOF

# --- main.jsx with providers ---
cat > client/src/main.jsx <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.jsx';
import './index.css';
import { ThemeProvider } from './contexts/ThemeContext';
import { LangProvider } from './contexts/LangContext';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <ThemeProvider>
      <LangProvider>
        <App />
      </LangProvider>
    </ThemeProvider>
  </React.StrictMode>,
);
EOF

echo ""
echo "✅ Frontend upgraded."
echo ""
echo "NEXT STEPS:"
echo "  1. Edit server-python/.env and add GEMINI_API_KEY"
echo "  2. cd server-python && .venv\\Scripts\\activate && pip install -r requirements.txt"
echo "  3. cd server-node && npm run seed"
echo "  4. Restart all three servers"