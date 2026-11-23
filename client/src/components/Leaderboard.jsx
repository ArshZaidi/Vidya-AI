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
