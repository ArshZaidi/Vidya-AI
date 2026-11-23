export default function GamificationBar({ xp, credits, rank, streak }) {
  return (
    <div className="flex items-center gap-5 text-xs font-display tracking-wide">
      <span className="text-ink/50">Rank <span className="text-ink font-semibold">{rank}</span></span>
      <span className="text-ink/50">XP <span className="text-raspberry font-semibold">{xp}</span></span>
      <span className="text-ink/50">Credits <span className="text-ink font-semibold">{credits}</span></span>
      {streak > 0 && <span>🔥 {streak}</span>}
    </div>
  );
}
