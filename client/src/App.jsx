import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { api } from './api/client';
import { useGamification } from './hooks/useGamification';
import Sidebar from './components/Sidebar';
import ChapterViewer from './components/ChapterViewer';
import VideoPlayer from './components/VideoPlayer';
import ExerciseCard from './components/ExerciseCard';
import ChatPanel from './components/ChatPanel';
import ResourcesList from './components/ResourcesList';
import TopicSearch from './components/TopicSearch';
import GamificationBar from './components/GamificationBar';
import FeatureCards from './components/FeatureCards';
import AnimatedBackground from './components/AnimatedBackground';

export default function App() {
  const { xp, credits, rank, streak, awardForExercise } = useGamification();
  const [topics, setTopics] = useState([]);
  const [chapter, setChapter] = useState(null);
  const [exercises, setExercises] = useState([]);
  const [certs, setCerts] = useState({});
  const [resources, setResources] = useState({});
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [chatOpen, setChatOpen] = useState(true);

  const refreshTopics = () => {
    api.topics().then(({ data }) => setTopics(data.topics)).catch(() => {});
  };

  useEffect(() => {
    const syncFromUrl = async () => {
      const path = window.location.pathname.replace(/^\//, '').trim();

      if (!path) {
        setChapter(null);
        setExercises([]);
        setCerts({});
        setResources({});
        return;
      }
      try {
        const { data } = await api.chapter(path);
        setChapter(data);
        const [ex, ce, re] = await Promise.all([
          api.exercises(data.slug),
          api.certifications(data.slug),
          api.resources(data.slug),
        ]);
        setExercises(ex.data.exercises[data.slug] || []);
        setCerts(ce.data.certifications);
        setResources(re.data.resources);
      } catch {
        window.history.replaceState(null, '', '/');
        setChapter(null);
        setExercises([]);
        setCerts({});
        setResources({});
      }
    };

    syncFromUrl();
    refreshTopics();
    window.addEventListener('popstate', syncFromUrl);
    return () => window.removeEventListener('popstate', syncFromUrl);
  }, []);

  const loadChapter = (data) => {
    window.history.pushState(null, '', `/${data.slug}`);
    setChapter(data);
    api.exercises(data.slug).then((ex) =>
      setExercises(ex.data.exercises[data.slug] || [])
    );
    api.certifications(data.slug).then((ce) => setCerts(ce.data.certifications));
    api.resources(data.slug).then((re) => setResources(re.data.resources));
    refreshTopics();
    if (window.innerWidth < 1280) setChatOpen(false);
  };

  const loadBySlug = async (slug) => {
    const { data } = await api.chapter(slug);
    loadChapter(data);
  };

  const goHome = () => {
    window.history.pushState(null, '', '/');
    setChapter(null);
    setExercises([]);
    setCerts({});
    setResources({});
  };

  return (
    <div className="flex h-screen overflow-hidden bg-bg text-ink">
      <AnimatePresence initial={false}>
        {sidebarOpen && (
          <motion.div
            initial={{ width: 0, opacity: 0 }}
            animate={{ width: 288, opacity: 1 }}
            exit={{ width: 0, opacity: 0 }}
            transition={{ duration: 0.25, ease: [0.22, 1, 0.36, 1] }}
            className="overflow-hidden shrink-0"
          >
            <Sidebar
              topics={topics}
              currentSlug={chapter?.slug}
              onSelect={loadBySlug}
              onNew={goHome}
              onCollapse={() => setSidebarOpen(false)}
            />
          </motion.div>
        )}
      </AnimatePresence>

      <main className="flex-1 flex flex-col min-h-0 relative">
        <div className="shrink-0 z-10 bg-bg/80 backdrop-blur-md border-b border-ink/5 px-6 py-3 flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            {!sidebarOpen && (
              <button
                onClick={() => setSidebarOpen(true)}
                className="p-1.5 rounded-lg hover:bg-ink/5 text-ink/60 hover:text-ink transition-colors"
              >
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M3 6h18M3 12h18M3 18h18" />
                </svg>
              </button>
            )}
            {chapter ? (
              <button
                onClick={goHome}
                className="text-xs font-display uppercase tracking-wider text-ink/50 hover:text-raspberry transition-colors"
              >
                ← Home
              </button>
            ) : (
              <p className="font-body text-lg">
                SDG4 <span className="text-raspberry">Study</span>
              </p>
            )}
          </div>
          <GamificationBar xp={xp} credits={credits} rank={rank} streak={streak} />
        </div>

        <div className={`flex-1 min-h-0 relative ${chapter ? 'overflow-y-auto' : 'overflow-hidden'}`}>
          <AnimatePresence mode="wait">
            {!chapter ? (
              /* ====================== PREMIUM HOME ====================== */
              <motion.div
                key="landing"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0, y: -8 }}
                transition={{ duration: 0.35 }}
                className="absolute inset-0 overflow-hidden flex flex-col"
              >
                <AnimatedBackground />

                {/* Top editorial band */}
                <motion.div
                  initial={{ opacity: 0, y: -6 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.05, duration: 0.6 }}
                  className="relative z-10 px-10 pt-8 pb-4 hidden sm:flex items-center justify-between"
                >
                  <p className="font-display uppercase text-[10px] tracking-[0.35em] text-ink/35">
                    SDG 4 / Quality Education
                  </p>
                  <p className="font-display uppercase text-[10px] tracking-[0.35em] text-ink/25">
                    Prototype · 2026
                  </p>
                </motion.div>

                {/* Center stage */}
                <div className="relative z-10 flex-1 flex flex-col items-center justify-center px-6 -mt-2">
                  {/* Pill eyebrow */}
                  <motion.div
                    initial={{ opacity: 0, y: 6 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.15, duration: 0.5 }}
                    className="inline-flex items-center gap-2.5 px-3.5 py-1.5 bg-ink/[0.04] border border-ink/10 rounded-full mb-7 backdrop-blur-sm"
                  >
                    <span
                      className="w-1.5 h-1.5 rounded-full bg-raspberry"
                      style={{ boxShadow: '0 0 10px rgb(var(--raspberry-rgb) / 0.7)' }}
                    />
                    <span className="font-display uppercase text-[10px] tracking-[0.3em] text-ink/60">
                      SDG 4 · Quality Education For All
                    </span>
                  </motion.div>

                  {/* Hero */}
                  <motion.h1
                    initial={{ opacity: 0, y: 24 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.28, duration: 0.85, ease: [0.22, 1, 0.36, 1] }}
                    className="font-body text-center leading-[0.94] tracking-[-0.015em] mb-6 px-2"
                    style={{ fontSize: 'clamp(2.5rem, 5.2vw, 4.5rem)' }}
                  >
                    Learn <em className="italic text-raspberry">anything,</em>
                    <br />
                    in <em className="italic text-ink/40">your</em> way.
                  </motion.h1>

                  {/* Breathing divider */}
                  <motion.div
                    initial={{ opacity: 0, scaleX: 0.4 }}
                    animate={{ opacity: 1, scaleX: 1 }}
                    transition={{ delay: 0.55, duration: 0.7 }}
                    className="flex items-center gap-3 mb-7"
                  >
                    <span className="h-px w-14 bg-ink/15" />
                    <span
                      className="w-1 h-1 rounded-full bg-raspberry"
                      style={{ boxShadow: '0 0 8px rgb(var(--raspberry-rgb) / 0.5)' }}
                    />
                    <span className="h-px w-14 bg-ink/15" />
                  </motion.div>

                  {/* Supporting line */}
                  <motion.p
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: 0.65, duration: 0.6 }}
                    className="font-body text-center text-sm md:text-base text-ink/55 max-w-md leading-relaxed mb-8"
                  >
                    Type any topic. Get a structured chapter with tables, video,
                    and exercises — in 12 Indian languages.
                  </motion.p>

                  {/* Search */}
                  <TopicSearch onLoad={loadChapter} />
                </div>

                {/* Bottom strip — features + footer */}
                <motion.div
                  initial={{ opacity: 0, y: 16 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.9, duration: 0.6 }}
                  className="relative z-10 px-10 pb-7 hidden md:block"
                >
                  <div className="max-w-4xl mx-auto border-t border-ink/10 pt-6">
                    <FeatureCards />
                  </div>
                  <div className="flex items-center justify-center gap-6 mt-6 text-[10px] font-display uppercase tracking-[0.25em] text-ink/30">
                    <span>Free forever</span>
                    <span className="w-1 h-1 rounded-full bg-ink/20" />
                    <span>No signup</span>
                    <span className="w-1 h-1 rounded-full bg-ink/20" />
                    <span>Runs on your device</span>
                  </div>
                </motion.div>
              </motion.div>
            ) : (
              /* ====================== CHAPTER ====================== */
              <motion.div
                key="chapter"
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -8 }}
                transition={{ duration: 0.35, ease: [0.22, 1, 0.36, 1] }}
                className="px-6 lg:px-10 py-8 max-w-3xl mx-auto"
              >
                <ChapterViewer chapter={chapter} />
                <VideoPlayer chapter={chapter} />
                <ExerciseCard exercises={exercises} onComplete={awardForExercise} />
                <ResourcesList certifications={certs} resources={resources} />
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </main>

      <AnimatePresence initial={false}>
        {chatOpen && chapter && (
          <motion.div
            initial={{ width: 0, opacity: 0 }}
            animate={{ width: 380, opacity: 1 }}
            exit={{ width: 0, opacity: 0 }}
            transition={{ duration: 0.25, ease: [0.22, 1, 0.36, 1] }}
            className="overflow-hidden shrink-0 hidden lg:block"
          >
            <ChatPanel chapter={chapter} onCollapse={() => setChatOpen(false)} />
          </motion.div>
        )}
      </AnimatePresence>

      {chapter && !chatOpen && (
        <motion.button
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          onClick={() => setChatOpen(true)}
          className="fixed bottom-6 right-6 z-20 px-4 py-3 bg-raspberry text-white rounded-full shadow-lg hover:opacity-90 font-display text-sm hidden lg:flex items-center gap-2"
        >
          ✦ Open AI Tutor
        </motion.button>
      )}
    </div>
  );
}
