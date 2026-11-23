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
