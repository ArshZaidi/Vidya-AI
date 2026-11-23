export default function AnimatedBackground() {
  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none" aria-hidden="true">
      {/* Raspberry glow — top left */}
      <div
        className="absolute top-[-10%] left-[10%] w-[600px] h-[600px] rounded-full animate-float-slow"
        style={{
          background: 'radial-gradient(circle, rgb(var(--raspberry-rgb) / 0.12) 0%, transparent 65%)',
          filter: 'blur(100px)',
        }}
      />
      {/* Pistachio glow — bottom right */}
      <div
        className="absolute bottom-[-15%] right-[5%] w-[700px] h-[700px] rounded-full animate-float-slow"
        style={{
          background: 'radial-gradient(circle, rgb(var(--pistachio-rgb) / 0.22) 0%, transparent 65%)',
          filter: 'blur(120px)',
          animationDelay: '-8s',
        }}
      />
      {/* Bronze glow — center right */}
      <div
        className="absolute top-[40%] right-[30%] w-[400px] h-[400px] rounded-full animate-float-slow"
        style={{
          background: 'radial-gradient(circle, rgb(var(--bronze-rgb) / 0.10) 0%, transparent 70%)',
          filter: 'blur(80px)',
          animationDelay: '-15s',
        }}
      />
      {/* Film grain — subtle texture */}
      <div
        className="absolute inset-0 opacity-[0.035] mix-blend-overlay"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 300 300' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E")`,
          backgroundSize: '300px 300px',
        }}
      />
    </div>
  );
}
