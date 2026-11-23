export default function ResourcesList({ certifications, resources }) {
  const certList = Object.values(certifications || {}).flat();
  const resList = Object.values(resources || {}).flat();
  if (!certList.length && !resList.length) return null;
  return (
    <div className="mt-16 grid gap-8 md:grid-cols-2">
      <div>
        <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry mb-3">
          Certifications
        </p>
        <ul className="space-y-2">
          {certList.map((c) => (
            <li key={c.title}>
              <a href={c.url} target="_blank" rel="noreferrer"
                className="block p-4 rounded-2xl bg-surface border border-ink/10 hover:border-raspberry transition-colors">
                <p className="font-body text-lg text-ink">{c.title}</p>
                <p className="text-xs text-ink/40 mt-1 truncate">{c.url}</p>
              </a>
            </li>
          ))}
        </ul>
      </div>
      <div>
        <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry mb-3">
          Trusted Resources
        </p>
        <ul className="space-y-2">
          {resList.map((r) => (
            <li key={r.title}>
              <a href={r.url} target="_blank" rel="noreferrer"
                className="block p-4 rounded-2xl bg-surface border border-ink/10 hover:border-raspberry transition-colors">
                <p className="font-body text-lg text-ink">{r.title}</p>
                <p className="text-xs text-ink/40 mt-1">{r.type}</p>
              </a>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
