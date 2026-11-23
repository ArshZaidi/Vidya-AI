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
