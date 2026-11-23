#!/usr/bin/env bash
set -euo pipefail

# Ensure dirs exist (idempotent)
mkdir -p client/src/api client/src/hooks client/src/components

# ---------- 1. API client ----------
cat > client/src/api/client.js <<'EOF'
import axios from "axios";

const node = axios.create({ baseURL: "/api", timeout: 15000 });
const ai   = axios.create({ baseURL: "/ai",  timeout: 30000 });

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
  tts:           (text, language = "en") =>
    ai.post("/tts", { text, language }),
};
EOF

# ---------- 2. useGamification ----------
cat > client/src/hooks/useGamification.js <<'EOF'
import { useState, useEffect, useCallback } from "react";

const KEY = "sdg4-gamification";
const DEFAULTS = { xp: 0, credits: 0, completedExercises: [], streak: 0, lastActive: null };

const read = () => {
  try { return { ...DEFAULTS, ...JSON.parse(localStorage.getItem(KEY) || "{}") }; }
  catch { return { ...DEFAULTS }; }
};

export const XP_PER_EXERCISE = 50;
export const CREDITS_PER_EXERCISE = 10;

export function useGamification() {
  const [state, setState] = useState(read);

  useEffect(() => {
    localStorage.setItem(KEY, JSON.stringify(state));
  }, [state]);

  const awardForExercise = useCallback((exerciseId) => {
    setState((s) => {
      if (s.completedExercises.includes(exerciseId)) return s;
      const today = new Date().toDateString();
      const streak = s.lastActive === today ? s.streak : s.streak + 1;
      return {
        xp: s.xp + XP_PER_EXERCISE,
        credits: s.credits + CREDITS_PER_EXERCISE,
        completedExercises: [...s.completedExercises, exerciseId],
        streak,
        lastActive: today,
      };
    });
  }, []);

  const reset = useCallback(() => setState({ ...DEFAULTS }), []);

  const rank = state.xp >= 2000 ? "Scholar" : state.xp >= 1000 ? "Explorer" : state.xp >= 300 ? "Learner" : "Beginner";

  return { ...state, rank, awardForExercise, reset };
}
EOF

# ---------- 3. useSmoothScroll ----------
cat > client/src/hooks/useSmoothScroll.js <<'EOF'
import { useEffect } from "react";
import Lenis from "lenis";

export function useSmoothScroll() {
  useEffect(() => {
    const lenis = new Lenis({
      duration: 1.2,
      easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      smoothWheel: true,
    });

    let raf;
    const loop = (time) => {
      lenis.raf(time);
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);

    return () => {
      cancelAnimationFrame(raf);
      lenis.destroy();
    };
  }, []);
}
EOF

# ---------- 4. MagneticButton ----------
cat > client/src/components/MagneticButton.jsx <<'EOF'
import { useRef } from "react";
import { motion, useMotionValue, useSpring } from "framer-motion";

export default function MagneticButton({ children, className = "", strength = 0.35, ...props }) {
  const ref = useRef(null);
  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const sx = useSpring(x, { stiffness: 250, damping: 18 });
  const sy = useSpring(y, { stiffness: 250, damping: 18 });

  const onMove = (e) => {
    const rect = ref.current.getBoundingClientRect();
    const relX = e.clientX - rect.left - rect.width / 2;
    const relY = e.clientY - rect.top - rect.height / 2;
    x.set(relX * strength);
    y.set(relY * strength);
  };
  const onLeave = () => { x.set(0); y.set(0); };

  return (
    <motion.button
      ref={ref}
      onMouseMove={onMove}
      onMouseLeave={onLeave}
      style={{ x: sx, y: sy }}
      whileTap={{ scale: 0.97 }}
      className={`relative inline-flex items-center justify-center ${className}`}
      {...props}
    >
      {children}
    </motion.button>
  );
}
EOF

# ---------- 5. TopicSearch ----------
cat > client/src/components/TopicSearch.jsx <<'EOF'
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { api } from "../api/client";
import MagneticButton from "./MagneticButton";

const SUGGESTIONS = ["photosynthesis", "newtons-laws", "python-basics"];

export default function TopicSearch({ onLoad }) {
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const submit = async (e) => {
    e?.preventDefault();
    if (!query.trim()) return;
    setLoading(true);
    setError("");
    try {
      const { data } = await api.search(query.trim());
      onLoad(data);
    } catch (err) {
      setError(err.response?.data?.error || "Could not load topic");
    } finally {
      setLoading(false);
    }
  };

  return (
    <motion.section
      initial={{ opacity: 0, y: 30 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
      className="w-full max-w-3xl mx-auto"
    >
      <form onSubmit={submit} className="relative">
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="What do you want to study today?"
          className="w-full px-8 py-6 text-xl font-body bg-white/70 backdrop-blur border-2 border-ink/10 rounded-full text-ink placeholder:text-ink/30 outline-none focus:border-raspberry transition-colors shadow-[0_8px_40px_rgba(20,20,20,0.06)]"
        />
        <MagneticButton
          type="submit"
          disabled={loading}
          className="absolute right-3 top-1/2 -translate-y-1/2 px-8 py-4 bg-raspberry text-white font-display font-semibold rounded-full tracking-wide hover:bg-raspberry/90 disabled:opacity-60 shadow-[0_6px_20px_rgba(233,20,94,0.35)]"
        >
          {loading ? "..." : "Begin"}
        </MagneticButton>
      </form>

      <div className="mt-6 flex flex-wrap gap-2 justify-center">
        {SUGGESTIONS.map((s) => (
          <button
            key={s}
            onClick={() => { setQuery(s); }}
            className="px-4 py-1.5 text-sm font-display uppercase tracking-wider text-ink/60 border border-ink/15 rounded-full hover:bg-pistachio/60 hover:text-ink transition-colors"
          >
            {s.replace("-", " ")}
          </button>
        ))}
      </div>

      <AnimatePresence>
        {error && (
          <motion.p
            initial={{ opacity: 0, y: -6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0 }}
            className="mt-4 text-center text-sm text-raspberry"
          >
            {error}
          </motion.p>
        )}
      </AnimatePresence>
    </motion.section>
  );
}
EOF

# ---------- 6. LanguageToggle ----------
cat > client/src/components/LanguageToggle.jsx <<'EOF'
import { motion } from "framer-motion";

const LANGS = [
  { code: "en", label: "EN" },
  { code: "hi", label: "हिं" },
  { code: "es", label: "ES" },
  { code: "fr", label: "FR" },
  { code: "ta", label: "த" },
];

export default function LanguageToggle({ value, onChange }) {
  return (
    <div className="inline-flex p-1 bg-ink/5 rounded-full">
      {LANGS.map((l) => {
        const active = value === l.code;
        return (
          <button
            key={l.code}
            onClick={() => onChange(l.code)}
            className="relative px-4 py-2 text-sm font-display font-medium tracking-wide rounded-full"
          >
            {active && (
              <motion.span
                layoutId="lang-pill"
                className="absolute inset-0 bg-ink rounded-full"
                transition={{ type: "spring", stiffness: 400, damping: 30 }}
              />
            )}
            <span className={`relative z-10 ${active ? "text-pistachio" : "text-ink/60"}`}>
              {l.label}
            </span>
          </button>
        );
      })}
    </div>
  );
}
EOF

# ---------- 7. ChapterViewer ----------
cat > client/src/components/ChapterViewer.jsx <<'EOF'
import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { api } from "../api/client";
import LanguageToggle from "./LanguageToggle";
import MagneticButton from "./MagneticButton";

export default function ChapterViewer({ chapter }) {
  const [lang, setLang] = useState("en");
  const [sections, setSections] = useState(chapter.sections);
  const [translating, setTranslating] = useState(false);
  const [speaking, setSpeaking] = useState(false);

  useEffect(() => {
    setSections(chapter.sections);
    setLang("en");
  }, [chapter]);

  const translateAll = async (target) => {
    setLang(target);
    if (target === "en") {
      setSections(chapter.sections);
      return;
    }
    setTranslating(true);
    try {
      const translated = await Promise.all(
        chapter.sections.map(async (s) => {
          const [h, b] = await Promise.all([
            api.translate(s.heading, target),
            api.translate(s.body, target),
          ]);
          return { heading: h.data.translated_text, body: b.data.translated_text };
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
    if (!("speechSynthesis" in window)) return;
    if (speaking) {
      window.speechSynthesis.cancel();
      setSpeaking(false);
      return;
    }
    const text = sections.map((s) => `${s.heading}. ${s.body}`).join(". ");
    const u = new SpeechSynthesisUtterance(text);
    u.lang = lang === "hi" ? "hi-IN" : lang === "ta" ? "ta-IN" : "en-US";
    u.onend = () => setSpeaking(false);
    window.speechSynthesis.speak(u);
    setSpeaking(true);
  };

  const downloadNotes = () => {
    const md = `# ${chapter.title}\n\n${sections
      .map((s) => `## ${s.heading}\n\n${s.body}`)
      .join("\n\n")}`;
    const blob = new Blob([md], { type: "text/markdown" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `${chapter.slug}-notes.md`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <motion.article
      initial={{ opacity: 0, y: 40 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
      className="max-w-3xl mx-auto"
    >
      <div className="flex flex-wrap items-center justify-between gap-4 mb-8">
        <div>
          <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry">
            {chapter.subject} · {chapter.readingTimeMinutes} min read
          </p>
          <h2 className="font-body text-5xl md:text-6xl mt-2 leading-none">{chapter.title}</h2>
        </div>
        <LanguageToggle value={lang} onChange={translateAll} />
      </div>

      <div className="flex flex-wrap gap-3 mb-10">
        <MagneticButton
          onClick={speak}
          className="px-6 py-3 bg-ink text-pistachio rounded-full font-display text-sm tracking-wider"
        >
          {speaking ? "◼ Stop" : "▶ Listen"}
        </MagneticButton>
        <MagneticButton
          onClick={downloadNotes}
          className="px-6 py-3 bg-pistachio text-ink rounded-full font-display text-sm tracking-wider"
        >
          ↓ Download Notes
        </MagneticButton>
      </div>

      <div className={`space-y-10 ${translating ? "opacity-50 transition-opacity" : ""}`}>
        {sections.map((s, i) => (
          <motion.section
            key={i}
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-80px" }}
            transition={{ duration: 0.6, delay: i * 0.05 }}
          >
            <h3 className="font-display text-2xl font-semibold mb-3 text-ink">{s.heading}</h3>
            <p className="font-body text-lg leading-relaxed text-ink/80 whitespace-pre-line">
              {s.body}
            </p>
          </motion.section>
        ))}
      </div>

      {chapter.keyTerms?.length > 0 && (
        <div className="mt-16 p-6 bg-pistachio/40 rounded-3xl">
          <p className="font-display uppercase text-xs tracking-[0.2em] text-ink/60 mb-4">
            Key Terms
          </p>
          <div className="grid gap-4 md:grid-cols-2">
            {chapter.keyTerms.map((k) => (
              <div key={k.term}>
                <p className="font-display font-semibold">{k.term}</p>
                <p className="font-body text-ink/70 text-sm">{k.definition}</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </motion.article>
  );
}
EOF

# ---------- 8. VideoPlayer ----------
cat > client/src/components/VideoPlayer.jsx <<'EOF'
export default function VideoPlayer({ chapter }) {
  if (!chapter?.subtitlesUrl) return null;
  return (
    <div className="max-w-3xl mx-auto mt-16">
      <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry mb-3">
        Video Lesson · Subtitled
      </p>
      <div className="rounded-3xl overflow-hidden bg-ink shadow-2xl">
        <video
          controls
          className="w-full aspect-video"
          src={chapter.videoUrl || ""}
          poster=""
        >
          <track
            kind="captions"
            src={chapter.subtitlesUrl}
            srcLang="en"
            label="English"
            default
          />
        </video>
        {!chapter.videoUrl && (
          <p className="text-center text-pistachio/60 text-sm py-4 font-body">
            Subtitles loaded · awaiting video source (add `videoUrl` to the chapter JSON)
          </p>
        )}
      </div>
    </div>
  );
}
EOF

# ---------- 9. ExerciseCard ----------
cat > client/src/components/ExerciseCard.jsx <<'EOF'
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import MagneticButton from "./MagneticButton";

export default function ExerciseCard({ exercises, onComplete }) {
  const list = Array.isArray(exercises) ? exercises : [];
  const [answers, setAnswers] = useState({});
  const [results, setResults] = useState({});

  if (!list.length) return null;

  const submit = (ex) => {
    const userAnswer = (answers[ex.id] || "").trim();
    const correct =
      ex.type === "multiple-choice"
        ? userAnswer === ex.answer
        : userAnswer.length > 0;
    setResults((r) => ({ ...r, [ex.id]: correct }));
    if (correct) onComplete?.(ex.id);
  };

  return (
    <div className="max-w-3xl mx-auto mt-20">
      <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry mb-3">
        Practical Exercise
      </p>
      <div className="space-y-6">
        {list.map((ex) => {
          const done = ex.id in results;
          return (
            <motion.div
              key={ex.id}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              className="p-8 bg-white rounded-3xl border border-ink/10 shadow-[0_10px_40px_rgba(20,20,20,0.05)]"
            >
              <p className="font-body text-xl mb-6">{ex.question}</p>

              {ex.type === "multiple-choice" && (
                <div className="grid gap-3 md:grid-cols-2 mb-6">
                  {ex.options.map((opt) => (
                    <button
                      key={opt}
                      onClick={() => setAnswers((a) => ({ ...a, [ex.id]: opt }))}
                      disabled={done}
                      className={`text-left px-5 py-3 rounded-2xl border-2 transition-all font-body ${
                        answers[ex.id] === opt
                          ? "border-raspberry bg-raspberry/10"
                          : "border-ink/10 hover:border-ink/30"
                      } disabled:opacity-60`}
                    >
                      {opt}
                    </button>
                  ))}
                </div>
              )}

              {ex.type === "coding" && (
                <textarea
                  value={answers[ex.id] || ""}
                  onChange={(e) => setAnswers((a) => ({ ...a, [ex.id]: e.target.value }))}
                  disabled={done}
                  rows={4}
                  className="w-full p-4 font-mono text-sm bg-ink/5 rounded-2xl outline-none focus:ring-2 focus:ring-raspberry"
                  placeholder="Write your answer..."
                />
              )}

              <div className="mt-6 flex items-center gap-4">
                <MagneticButton
                  onClick={() => submit(ex)}
                  disabled={done}
                  className="px-6 py-3 bg-ink text-pistachio rounded-full font-display text-sm tracking-wider disabled:opacity-40"
                >
                  {done ? "Completed ✓" : "Check Answer"}
                </MagneticButton>
                <AnimatePresence>
                  {done && (
                    <motion.span
                      initial={{ opacity: 0, x: -10 }}
                      animate={{ opacity: 1, x: 0 }}
                      className={`font-display text-sm ${results[ex.id] ? "text-green-600" : "text-raspberry"}`}
                    >
                      {results[ex.id] ? `+50 XP · +10 credits` : "Try again"}
                    </motion.span>
                  )}
                </AnimatePresence>
              </div>

              {done && results[ex.id] && ex.explanation && (
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

# ---------- 10. GamificationBar ----------
cat > client/src/components/GamificationBar.jsx <<'EOF'
import { motion } from "framer-motion";

export default function GamificationBar({ xp, credits, rank, streak }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: -20 }}
      animate={{ opacity: 1, y: 0 }}
      className="fixed top-0 left-0 right-0 z-40 backdrop-blur-xl bg-white/70 border-b border-ink/5"
    >
      <div className="max-w-5xl mx-auto px-6 py-3 flex items-center justify-between">
        <p className="font-body text-xl">
          SDG4 <span className="text-raspberry">Study</span>
        </p>
        <div className="flex items-center gap-6 text-sm font-display tracking-wide">
          <span className="text-ink/60">Rank <span className="text-ink font-semibold">{rank}</span></span>
          <span className="text-ink/60">XP <span className="text-raspberry font-semibold">{xp}</span></span>
          <span className="text-ink/60">Credits <span className="text-ink font-semibold">{credits}</span></span>
          {streak > 0 && <span>🔥 {streak}</span>}
        </div>
      </div>
    </motion.div>
  );
}
EOF

# ---------- 11. Leaderboard ----------
cat > client/src/components/Leaderboard.jsx <<'EOF'
import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { api } from "../api/client";

export default function Leaderboard({ localXP, localCredits }) {
  const [users, setUsers] = useState([]);

  useEffect(() => {
    api.leaderboard().then(({ data }) => {
      const merged = data.users.map((u) =>
        u.isDemoUser ? { ...u, xp: localXP, credits: localCredits } : u
      );
      merged.sort((a, b) => b.xp - a.xp);
      setUsers(merged.map((u, i) => ({ ...u, rank: i + 1 })));
    });
  }, [localXP, localCredits]);

  return (
    <div className="max-w-xl mx-auto mt-20">
      <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry mb-6 text-center">
        Leaderboard
      </p>
      <div className="space-y-2">
        {users.map((u) => (
          <motion.div
            key={u.name}
            layout
            className={`flex items-center justify-between px-6 py-4 rounded-2xl ${
              u.isDemoUser
                ? "bg-pistachio text-ink shadow-lg"
                : "bg-white/60 border border-ink/5"
            }`}
          >
            <div className="flex items-center gap-4">
              <span className="font-display font-bold text-lg w-6 text-ink/40">{u.rank}</span>
              <span className="font-body text-lg">{u.name}</span>
            </div>
            <div className="flex gap-6 text-sm font-display">
              <span className="text-ink/60">XP <span className="text-ink font-semibold">{u.xp}</span></span>
              <span className="text-ink/60">CR <span className="text-ink font-semibold">{u.credits}</span></span>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
EOF

# ---------- 12. ResourcesList ----------
cat > client/src/components/ResourcesList.jsx <<'EOF'
export default function ResourcesList({ certifications, resources }) {
  return (
    <div className="max-w-3xl mx-auto mt-20 grid gap-10 md:grid-cols-2">
      <div>
        <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry mb-4">
          Certifications
        </p>
        <ul className="space-y-3">
          {Object.values(certifications || {}).flat().map((c) => (
            <li key={c.title}>
              <a
                href={c.url}
                target="_blank"
                rel="noreferrer"
                className="block p-4 rounded-2xl bg-white/60 border border-ink/5 hover:border-raspberry transition-colors"
              >
                <p className="font-body text-lg">{c.title}</p>
                <p className="text-xs text-ink/40 mt-1 truncate">{c.url}</p>
              </a>
            </li>
          ))}
        </ul>
      </div>
      <div>
        <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry mb-4">
          Trusted Resources
        </p>
        <ul className="space-y-3">
          {Object.values(resources || {}).flat().map((r) => (
            <li key={r.title}>
              <a
                href={r.url}
                target="_blank"
                rel="noreferrer"
                className="block p-4 rounded-2xl bg-white/60 border border-ink/5 hover:border-raspberry transition-colors"
              >
                <p className="font-body text-lg">{r.title}</p>
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

# ---------- 13. App.jsx ----------
cat > client/src/App.jsx <<'EOF'
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { api } from "./api/client";
import { useGamification } from "./hooks/useGamification";
import { useSmoothScroll } from "./hooks/useSmoothScroll";
import TopicSearch from "./components/TopicSearch";
import ChapterViewer from "./components/ChapterViewer";
import VideoPlayer from "./components/VideoPlayer";
import ExerciseCard from "./components/ExerciseCard";
import GamificationBar from "./components/GamificationBar";
import Leaderboard from "./components/Leaderboard";
import ResourcesList from "./components/ResourcesList";
import MagneticButton from "./components/MagneticButton";

export default function App() {
  useSmoothScroll();
  const { xp, credits, rank, streak, awardForExercise } = useGamification();
  const [chapter, setChapter] = useState(null);
  const [exercises, setExercises] = useState([]);
  const [certs, setCerts] = useState({});
  const [resources, setResources] = useState({});
  const [showLeaderboard, setShowLeaderboard] = useState(false);

  const loadChapter = async (data) => {
    setChapter(data);
    setShowLeaderboard(false);
    const [ex, ce, re] = await Promise.all([
      api.exercises(data.slug),
      api.certifications(data.slug),
      api.resources(data.slug),
    ]);
    setExercises(ex.data.exercises[data.slug] || []);
    setCerts(ce.data.certifications);
    setResources(re.data.resources);
  };

  const reset = () => {
    setChapter(null);
    setExercises([]);
    setCerts({});
    setResources({});
    setShowLeaderboard(false);
  };

  return (
    <div className="min-h-screen bg-[#FAFAF7]">
      <GamificationBar xp={xp} credits={credits} rank={rank} streak={streak} />

      <main className="pt-28 pb-24 px-6">
        <AnimatePresence mode="wait">
          {!chapter ? (
            <motion.div
              key="landing"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="flex flex-col items-center min-h-[70vh] justify-center"
            >
              <motion.h1
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.2 }}
                className="font-body text-6xl md:text-8xl text-center leading-[0.9] mb-4"
              >
                Learn <em className="text-raspberry">anything</em>,<br />
                in your <span className="text-ink/40">way.</span>
              </motion.h1>
              <p className="font-display uppercase text-xs tracking-[0.25em] text-ink/40 mb-16">
                SDG 4 · Quality Education For All
              </p>

              <TopicSearch onLoad={loadChapter} />

              <MagneticButton
                onClick={() => setShowLeaderboard((s) => !s)}
                className="mt-16 px-6 py-3 text-sm font-display uppercase tracking-wider text-ink/60 hover:text-raspberry transition-colors"
              >
                {showLeaderboard ? "↑ Back" : "View Leaderboard →"}
              </MagneticButton>

              {showLeaderboard && (
                <motion.div
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  className="w-full mt-10"
                >
                  <Leaderboard localXP={xp} localCredits={credits} />
                </motion.div>
              )}
            </motion.div>
          ) : (
            <motion.div
              key="chapter"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
            >
              <div className="max-w-3xl mx-auto mb-6">
                <button
                  onClick={reset}
                  className="text-sm font-display uppercase tracking-wider text-ink/40 hover:text-raspberry transition-colors"
                >
                  ← New topic
                </button>
              </div>

              <ChapterViewer chapter={chapter} />
              <VideoPlayer chapter={chapter} />
              <ExerciseCard exercises={exercises} onComplete={awardForExercise} />
              <ResourcesList certifications={certs} resources={resources} />
            </motion.div>
          )}
        </AnimatePresence>
      </main>
    </div>
  );
}
EOF

# ---------- 14. index.css ----------
cat > client/src/index.css <<'EOF'
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
  overflow-x: hidden;
}

/* Lenis smooth scroll requires this */
html.lenis, html.lenis body { height: auto; }
.lenis.lenis-smooth { scroll-behavior: auto !important; }
.lenis.lenis-smooth [data-lenis-prevent] { overscroll-behavior: contain; }
.lenis.lenis-stopped { overflow: hidden; }

::selection { background: var(--color-raspberry); color: white; }

::-webkit-scrollbar { width: 10px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: rgba(20,20,20,0.15); border-radius: 5px; }
::-webkit-scrollbar-thumb:hover { background: var(--color-raspberry); }
EOF

echo ""
echo "✅ Frontend populated — 14 files written."
echo ""
echo "Next:"
echo "  cd client && npm install && npm run dev"
echo "  (make sure server-node (3000) and server-python (8000) are running)"
echo ""
echo "Open http://localhost:5173"