import { motion } from 'framer-motion';

const FEATURES = [
  { num: '01', title: 'Any topic',    body: 'AI writes a full, structured chapter in seconds.',          accent: 'raspberry', icon: '✦' },
  { num: '02', title: '12 languages', body: 'Real script per language — Devanagari, Bengali, Tamil, more.', accent: 'pistachio', icon: '◐' },
  { num: '03', title: 'Accessible',   body: 'Text-to-speech and subtitles. Free, forever.',               accent: 'bronze',    icon: '◍' },
  { num: '04', title: 'AI tutor',     body: 'Follow-ups, examples, quizzes — all in context.',            accent: 'ink',       icon: '◇' },
];

export default function FeatureCards() {
  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-x-6 gap-y-5 lg:gap-x-0 w-full">
      {FEATURES.map((f, i) => (
        <motion.div
          key={f.title}
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.9 + i * 0.08, duration: 0.45, ease: [0.22, 1, 0.36, 1] }}
          className={`relative lg:px-6 ${i > 0 ? 'lg:border-l lg:border-ink/10' : ''}`}
        >
          <div className="flex items-center gap-2 mb-2.5">
            <span
              className="font-body italic text-[10px] tabular-nums leading-none"
              style={{ color: `rgb(var(--${f.accent}-rgb) / 0.7)` }}
            >
              {f.num}
            </span>
            <span
              className="text-[13px] leading-none"
              style={{ color: `rgb(var(--${f.accent}-rgb))` }}
            >
              {f.icon}
            </span>
          </div>
          <h3 className="font-display uppercase text-[10px] tracking-[0.22em] font-semibold text-ink mb-1.5">
            {f.title}
          </h3>
          <p className="text-[11px] text-ink/55 leading-[1.5]">{f.body}</p>
        </motion.div>
      ))}
    </div>
  );
}
