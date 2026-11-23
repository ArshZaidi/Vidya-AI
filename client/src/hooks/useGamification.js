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
