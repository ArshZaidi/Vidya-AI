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
