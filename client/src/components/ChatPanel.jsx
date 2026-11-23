import { useState, useRef, useEffect } from 'react';
import { motion } from 'framer-motion';
import { api } from '../api/client';
import { useLang } from '../contexts/LangContext';
import MagneticButton from './MagneticButton';

export default function ChatPanel({ chapter, onCollapse }) {
  const { lang } = useLang();
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const scrollRef = useRef(null);

  useEffect(() => {
    setMessages(chapter ? [{
      role: 'assistant',
      content: `I've read "${chapter.title}". Ask anything — follow-ups, examples, a quiz, or a simpler explanation.`,
    }] : []);
  }, [chapter]);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' });
  }, [messages, loading]);

  useEffect(() => {
    if (!loading) { setElapsed(0); return; }
    const t = setInterval(() => setElapsed((e) => e + 1), 1000);
    return () => clearInterval(t);
  }, [loading]);

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
      const { data } = await api.chat({ messages: next, context, language: lang });
      setMessages([...next, { role: 'assistant', content: data.reply }]);
    } catch (err) {
      setMessages([...next, {
        role: 'assistant',
        content: `⚠ ${err.response?.data?.detail || err.message}`,
      }]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="w-[380px] h-full flex flex-col bg-surface border-l border-ink/10 shrink-0">
      <div className="px-4 py-3 border-b border-ink/10 flex items-start justify-between">
        <div>
          <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry">AI Tutor</p>
          <p className="text-xs text-ink/50 mt-0.5 truncate max-w-[240px]">
            {chapter ? chapter.title : 'Load a chapter to begin'}
          </p>
        </div>
        <button
          onClick={onCollapse}
          className="p-1.5 rounded-lg hover:bg-ink/5 text-ink/50 hover:text-ink transition-colors"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M9 18l6-6-6-6" />
          </svg>
        </button>
      </div>

      <div ref={scrollRef} data-lenis-prevent className="flex-1 overflow-y-auto px-4 py-4 space-y-3">
        {messages.map((m, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}
          >
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
          <div className="flex items-center gap-2 px-4 py-3 bg-ink/5 rounded-2xl w-fit">
            {[0, 1, 2].map((i) => (
              <motion.div
                key={i}
                animate={{ opacity: [0.3, 1, 0.3], y: [0, -2, 0] }}
                transition={{ duration: 1.2, repeat: Infinity, delay: i * 0.2 }}
                className="w-1.5 h-1.5 rounded-full bg-ink/40"
              />
            ))}
            {elapsed > 5 && (
              <span className="text-[10px] text-ink/40 ml-1">{elapsed}s</span>
            )}
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
            className={`flex-1 px-3 py-2 text-sm bg-ink/5 rounded-xl outline-none focus:ring-2 focus:ring-raspberry text-ink placeholder:text-ink/30 disabled:opacity-50 content-${lang}`}
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
