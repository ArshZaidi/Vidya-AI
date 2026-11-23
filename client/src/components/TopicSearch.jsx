import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { api } from '../api/client';

const ROTATING = [
  'photosynthesis',
  'black holes',
  'game theory',
  'neural networks',
  'the cold war',
  'object oriented programming',
];

const CHIPS = ['object oriented programming', 'black holes', 'game theory'];

export default function TopicSearch({ onLoad }) {
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [hintIdx, setHintIdx] = useState(0);
  const [focused, setFocused] = useState(false);

  useEffect(() => {
    if (query) return;
    const t = setInterval(() => setHintIdx((i) => (i + 1) % ROTATING.length), 2800);
    return () => clearInterval(t);
  }, [query]);

  const submit = async (e) => {
    e?.preventDefault();
    if (!query.trim() || loading) return;
    setLoading(true);
    setError('');
    try {
      const { data } = await api.search(query.trim());
      onLoad(data);
    } catch (err) {
      if (err.code === 'ECONNABORTED') {
        setError('Generation timed out — try again.');
      } else {
        setError(err.response?.data?.error || err.response?.data?.detail || err.message);
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.7, duration: 0.55, ease: [0.22, 1, 0.36, 1] }}
      className="w-full max-w-xl px-4"
    >
      <form onSubmit={submit} className="relative group">
        {/* Focus glow */}
        <div
          className="absolute -inset-2 rounded-full pointer-events-none blur-xl transition-opacity duration-500"
          style={{
            background:
              'linear-gradient(90deg, rgb(var(--raspberry-rgb) / 0.35), rgb(var(--pistachio-rgb) / 0.35))',
            opacity: focused ? 1 : 0,
          }}
        />

        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          className="relative w-full px-7 py-5 pr-40 text-base font-body bg-surface border border-ink/10 rounded-full text-ink outline-none focus:border-raspberry/60 transition-all"
          style={{
            boxShadow:
              '0 10px 40px rgba(20,20,20,0.06), inset 0 1px 0 rgba(255,255,255,0.6)',
          }}
        />

        {/* Rotating hint */}
        {!query && (
          <div className="absolute left-7 top-1/2 -translate-y-1/2 pointer-events-none text-base font-body text-ink/30 flex items-center max-w-[calc(100%-12rem)] overflow-hidden">
            <span className="shrink-0">Study </span>
            <AnimatePresence mode="wait">
              <motion.span
                key={hintIdx}
                initial={{ opacity: 0, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -6 }}
                transition={{ duration: 0.4 }}
                className="ml-1 text-ink/55 italic truncate"
              >
                {ROTATING[hintIdx]}
              </motion.span>
            </AnimatePresence>
            <span className="ml-0.5 text-raspberry animate-cursor shrink-0">|</span>
          </div>
        )}

        {/* Submit */}
        <div className="absolute right-2 inset-y-0 flex items-center pr-1 pointer-events-none">
          <button
            type="submit"
            disabled={loading}
            className="pointer-events-auto px-6 py-3.5 bg-ink text-bg rounded-full font-display text-[11px] uppercase tracking-[0.18em] font-medium shadow-md flex items-center gap-2 hover:bg-raspberry hover:-translate-y-0.5 hover:shadow-lg transition-all duration-300 disabled:opacity-40 disabled:hover:translate-y-0 disabled:hover:bg-ink"
          >
            {loading ? (
              <>
                <motion.span
                  animate={{ rotate: 360 }}
                  transition={{ duration: 1, repeat: Infinity, ease: 'linear' }}
                  className="inline-block w-3 h-3 border-2 border-bg/40 border-t-bg rounded-full"
                />
                Writing
              </>
            ) : (
              <>
                Begin
                <span className="text-bg/60 group-hover:text-bg transition-colors">→</span>
              </>
            )}
          </button>
        </div>
      </form>

      {/* Chips — inline, elegant */}
      <div className="mt-5 flex items-center justify-center flex-wrap gap-x-3 gap-y-1 text-xs">
        <span className="font-display uppercase tracking-[0.22em] text-ink/30">Try</span>
        {CHIPS.map((s, i) => (
          <span key={s} className="flex items-center gap-3">
            {i > 0 && <span className="text-ink/15 select-none">·</span>}
            <button
              type="button"
              onClick={() => setQuery(s)}
              className="font-body italic text-ink/55 hover:text-raspberry transition-colors"
            >
              {s}
            </button>
          </span>
        ))}
      </div>

      <AnimatePresence>
        {error && (
          <motion.p
            initial={{ opacity: 0, y: -4 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0 }}
            className="mt-3 text-center text-xs text-raspberry"
          >
            {error}
          </motion.p>
        )}
      </AnimatePresence>
    </motion.div>
  );
}
