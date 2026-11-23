import { useTheme } from '../contexts/ThemeContext';
import { useLang } from '../contexts/LangContext';
import { LANGUAGES } from '../constants/languages';

export default function Sidebar({ topics, currentSlug, onSelect, onNew, onCollapse }) {
  const { theme, toggle } = useTheme();
  const { lang, setLang } = useLang();

  return (
    <aside className="w-72 h-full flex flex-col bg-surface border-r border-ink/10 p-4 shrink-0">
      <div className="flex items-center justify-between mb-6">
        <h1 className="font-body text-2xl">
          SDG4 <span className="text-raspberry">Study</span>
        </h1>
        <button
          onClick={onCollapse}
          className="p-1.5 rounded-lg hover:bg-ink/5 text-ink/50 hover:text-ink transition-colors"
          title="Hide sidebar"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M15 18l-6-6 6-6" />
          </svg>
        </button>
      </div>

      <button
        onClick={onNew}
        className="mb-5 w-full px-4 py-2 bg-raspberry text-white text-sm font-display rounded-xl hover:opacity-90 transition-opacity"
      >
        + New Topic
      </button>

      <div data-lenis-prevent className="flex-1 overflow-y-auto">
        <p className="font-display uppercase text-xs tracking-wider text-ink/40 mb-2">Your Library</p>
        <div className="space-y-1">
          {topics.length === 0 && (
            <p className="text-xs text-ink/40 italic px-3 py-2">No topics yet. Search or click "New Topic".</p>
          )}
          {topics.map((t) => (
            <button
              key={t.slug}
              onClick={() => onSelect(t.slug)}
              className={`w-full text-left px-3 py-2 rounded-lg transition-colors ${
                currentSlug === t.slug
                  ? 'bg-pistachio/40 text-ink'
                  : 'text-ink/70 hover:bg-ink/5'
              }`}
            >
              <p className="font-body text-sm truncate">{t.title}</p>
              <p className="text-[10px] uppercase tracking-wider text-ink/40 mt-0.5 truncate">
                {t.subject}
              </p>
            </button>
          ))}
        </div>
      </div>

      <div className="mt-4 pt-4 border-t border-ink/10 space-y-3">
        <div>
          <p className="font-display uppercase text-xs tracking-wider text-ink/40 mb-1.5">Language</p>
          <select
            value={lang}
            onChange={(e) => setLang(e.target.value)}
            className="w-full px-3 py-2 bg-ink/5 rounded-lg text-sm text-ink outline-none cursor-pointer"
          >
            {LANGUAGES.map((l) => (
              <option key={l.code} value={l.code}>{l.name}</option>
            ))}
          </select>
        </div>
        <button
          onClick={toggle}
          className="w-full px-3 py-2 bg-ink/5 hover:bg-ink/10 rounded-lg text-sm text-ink font-display transition-colors"
        >
          {theme === 'dark' ? '☀ Light Mode' : '☾ Dark Mode'}
        </button>
      </div>
    </aside>
  );
}
