#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 1. index.css — remove global transform overrides
# ============================================================

python3 - <<'PYEOF'
import re
path = "client/src/index.css"
css = open(path).read()

# Remove the two problematic rules
css = re.sub(
    r'button:not\(:disabled\):hover \{[^}]*\}',
    '/* (removed: broke absolutely-positioned buttons) */',
    css
)
css = re.sub(
    r'button:not\(:disabled\):active \{[^}]*\}',
    '/* (removed: broke absolutely-positioned buttons) */',
    css
)

open(path, "w").write(css)
print("✅ index.css: removed global transform hover/active rules")
PYEOF

# ============================================================
# 2. TopicSearch — wrap Begin button so it doesn't rely on transform
# ============================================================

python3 - <<'PYEOF'
path = "client/src/components/TopicSearch.jsx"
src = open(path).read()

old = '''        <button
          type="submit"
          disabled={loading}
          className="absolute right-2 top-1/2 -translate-y-1/2 px-6 py-3.5 bg-ink text-bg rounded-full font-display text-[11px] uppercase tracking-[0.18em] font-medium hover:bg-raspberry transition-colors duration-300 disabled:opacity-40 shadow-md flex items-center gap-2"
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
        </button>'''

new = '''        <div className="absolute right-2 inset-y-0 flex items-center pr-1 pointer-events-none">
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
        </div>'''

if old not in src:
    raise SystemExit("❌ Original Begin button block not found — no changes written")

src = src.replace(old, new)
open(path, "w").write(src)
print("✅ TopicSearch.jsx: Begin button wrapped, hover animation fixed")
PYEOF

echo ""
echo "🎯 What changed:"
echo "   • Removed the global 'button:hover { transform: translateY(-1px) }' rule"
echo "   • Begin button now centers via flex wrapper, not transform"
echo "   • Hover lift is 2px (subtle) with shadow boost + color change"
echo "   • transition-all makes it smooth (was transition-colors)"
echo ""
echo "No restart needed. Vite hot-reloads in ~1s. Just hover the button."