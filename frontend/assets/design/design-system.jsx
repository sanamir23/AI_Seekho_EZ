// design-system.jsx — EZ shared components & icons

// ─── EZ Logo (SVG recreation of the stacked "E/Z" mark)
function EZLogo({ size = 24, color = "#141414" }) {
  // Two parallelogram-style bars: top short bar + bottom longer bar with notched middle (Z-like)
  // Recreated from the supplied PNG.
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" fill="none" aria-label="EZ">
      {/* Top bar */}
      <path d="M18 22 L74 22 L82 38 L26 38 Z" fill={color} />
      {/* Middle/bottom Z form */}
      <path d="M18 46 L82 46 L82 60 L42 60 L82 62 L82 78 L18 78 L18 64 L58 64 L18 62 Z" fill={color} />
    </svg>);

}

// Simpler, cleaner reading of the logo — two stacked parallelogram bars
function EZMark({ size = 28, color = "#141414" }) {
  return (
    <svg width={size} height={size * (1080 / 1080)} viewBox="0 0 120 120" fill="none" aria-label="EZ">
      {/* top bar */}
      <path d="M22 26 H86 L98 42 H34 Z" fill={color} />
      {/* mid bar (slanted left edge) */}
      <path d="M22 50 H98 L98 66 H42 L98 72 L98 88 H22 L22 74 H78 L22 68 Z" fill={color} />
    </svg>);

}

// Use the PNG when we want fidelity, SVG when we want to color/scale freely.
function EZLogoImg({ size = 28 }) {
  return <img src="assets/ez-logo.png" width={size} height={size} alt="EZ" style={{ display: 'block', objectFit: 'contain' }} />;
}

// ─── Service icons (line, simple)
const Icon = {
  search: (c = "#141414", s = 18) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <circle cx="11" cy="11" r="7" stroke={c} strokeWidth="2" />
      <path d="M20 20l-3.5-3.5" stroke={c} strokeWidth="2" strokeLinecap="round" />
    </svg>,

  mic: (c = "#141414", s = 18) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <rect x="9" y="3" width="6" height="12" rx="3" stroke={c} strokeWidth="2" />
      <path d="M5 11a7 7 0 0 0 14 0M12 18v3" stroke={c} strokeWidth="2" strokeLinecap="round" />
    </svg>,

  pin: (c = "#141414", s = 14) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M12 22s7-7 7-12a7 7 0 1 0-14 0c0 5 7 12 7 12Z" stroke={c} strokeWidth="2" />
      <circle cx="12" cy="10" r="2.5" stroke={c} strokeWidth="2" />
    </svg>,

  chevDown: (c = "#141414", s = 14) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M6 9l6 6 6-6" stroke={c} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>,

  chevRight: (c = "#141414", s = 14) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M9 6l6 6-6 6" stroke={c} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>,

  bell: (c = "#141414", s = 20) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M6 16V11a6 6 0 1 1 12 0v5l1.5 2H4.5L6 16Z" stroke={c} strokeWidth="2" strokeLinejoin="round" />
      <path d="M10 20a2 2 0 0 0 4 0" stroke={c} strokeWidth="2" strokeLinecap="round" />
    </svg>,

  back: (c = "#141414", s = 18) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M15 6l-6 6 6 6" stroke={c} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>,

  star: (c = "#141414", filled = true, s = 14) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill={filled ? c : "none"} stroke={c} strokeWidth="1.5">
      <path d="M12 3l2.7 5.7 6.3.9-4.5 4.4 1.1 6.3L12 17.8 6.4 20.3l1.1-6.3L3 9.6l6.3-.9L12 3Z" />
    </svg>,

  brain: (c = "#141414", s = 18) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M9 5a3 3 0 0 0-3 3 3 3 0 0 0-2 5 3 3 0 0 0 2 4 3 3 0 0 0 3 3V5Z" stroke={c} strokeWidth="1.8" strokeLinejoin="round" />
      <path d="M15 5a3 3 0 0 1 3 3 3 3 0 0 1 2 5 3 3 0 0 1-2 4 3 3 0 0 1-3 3V5Z" stroke={c} strokeWidth="1.8" strokeLinejoin="round" />
    </svg>,

  radar: (c = "#141414", s = 18) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="9" stroke={c} strokeWidth="1.6" />
      <circle cx="12" cy="12" r="5" stroke={c} strokeWidth="1.6" />
      <path d="M12 12 L20 8" stroke={c} strokeWidth="1.8" strokeLinecap="round" />
      <circle cx="12" cy="12" r="1.6" fill={c} />
    </svg>,

  coin: (c = "#141414", s = 18) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="9" stroke={c} strokeWidth="1.8" />
      <path d="M9 9h5a2 2 0 0 1 0 4H9m0 0h6m-6 0v4" stroke={c} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>,

  cal: (c = "#141414", s = 18) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <rect x="3.5" y="5.5" width="17" height="15" rx="2.5" stroke={c} strokeWidth="1.8" />
      <path d="M3.5 10h17M8 3v4M16 3v4" stroke={c} strokeWidth="1.8" strokeLinecap="round" />
    </svg>,

  trophy: (c = "#141414", s = 18) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M7 4h10v5a5 5 0 0 1-10 0V4Z" stroke={c} strokeWidth="1.8" strokeLinejoin="round" />
      <path d="M7 6H4v2a3 3 0 0 0 3 3M17 6h3v2a3 3 0 0 1-3 3M9 20h6M12 14v6" stroke={c} strokeWidth="1.8" strokeLinecap="round" />
    </svg>,

  check: (c = "#141414", s = 14) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M5 12l4.5 4.5L19 7" stroke={c} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
    </svg>,

  sparkle: (c = "#141414", s = 14) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill={c}>
      <path d="M12 2l1.6 5.4L19 9l-5.4 1.6L12 16l-1.6-5.4L5 9l5.4-1.6L12 2Z" />
    </svg>,

  close: (c = "#141414", s = 16) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M6 6l12 12M18 6L6 18" stroke={c} strokeWidth="2.2" strokeLinecap="round" />
    </svg>,

  shield: (c = "#141414", s = 12) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill={c}>
      <path d="M12 2l8 3v6c0 5-3.5 9-8 11-4.5-2-8-6-8-11V5l8-3Z" />
      <path d="M8 12l3 3 5-6" stroke="#fff" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
    </svg>,

  home: (c = "#141414", s = 22) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M4 11l8-7 8 7v8a2 2 0 0 1-2 2h-3v-6h-6v6H6a2 2 0 0 1-2-2v-8Z" stroke={c} strokeWidth="1.8" strokeLinejoin="round" />
    </svg>,

  bag: (c = "#141414", s = 22) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M4 8h16l-1 12a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2L4 8Z" stroke={c} strokeWidth="1.8" strokeLinejoin="round" />
      <path d="M9 8V6a3 3 0 0 1 6 0v2" stroke={c} strokeWidth="1.8" />
    </svg>,

  msg: (c = "#141414", s = 22) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M4 6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H9l-4 4v-4H6a2 2 0 0 1-2-2V6Z" stroke={c} strokeWidth="1.8" strokeLinejoin="round" />
    </svg>,

  user: (c = "#141414", s = 22) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="8" r="4" stroke={c} strokeWidth="1.8" />
      <path d="M4 21c1-4 5-6 8-6s7 2 8 6" stroke={c} strokeWidth="1.8" strokeLinecap="round" />
    </svg>,

  ac: (c = "#141414", s = 22) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      {/* outer body */}
      <rect x="2.5" y="5" width="19" height="10" rx="2.5" stroke={c} strokeWidth="1.6" style={{ stroke: "rgb(20, 20, 20)" }} />
      {/* internal divider line */}
      <path d="M2.5 11h19" stroke={c} strokeWidth="1.4" />
      {/* vent louvers */}
      <path d="M5 8.4h6M5 9.6h6" stroke={c} strokeWidth="1" strokeLinecap="round" />
      {/* indicator dots */}
      <circle cx="17" cy="8.7" r=".9" fill={c} />
      <circle cx="19.2" cy="8.7" r=".9" fill={c} />
      {/* cool airflow streams */}
      <path d="M7 17c0 1 1 1 1 2M12 17c0 1 1 1 1 2M17 17c0 1 1 1 1 2" stroke={c} strokeWidth="1.4" strokeLinecap="round" />
      {/* tiny snowflake */}
      <path d="M12 19.5v2.2M11 20.6h2M11.3 19.8l1.4 1.4M11.3 21.2l1.4-1.4" stroke={c} strokeWidth="1" strokeLinecap="round" style={{ stroke: "rgb(252, 210, 74)" }} />
    </svg>,

  wrench: (c = "#141414", s = 22) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M14 4a5 5 0 0 1 6 6l-2 1-3-3 1-2a5 5 0 0 0-2-2ZM3 18l9-9 3 3-9 9-3-3Z" stroke={c} strokeWidth="1.6" strokeLinejoin="round" />
    </svg>,

  bolt: (c = "#141414", s = 22) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M13 2L4 14h6l-1 8 9-12h-6l1-8Z" stroke={c} strokeWidth="1.6" strokeLinejoin="round" />
    </svg>,

  book: (c = "#141414", s = 22) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M4 5a2 2 0 0 1 2-2h12v18H6a2 2 0 0 1-2-2V5Z" stroke={c} strokeWidth="1.6" strokeLinejoin="round" />
      <path d="M8 7h6M8 11h6" stroke={c} strokeWidth="1.6" strokeLinecap="round" />
    </svg>,

  scissors: (c = "#141414", s = 22) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <circle cx="6" cy="6" r="3" stroke={c} strokeWidth="1.6" />
      <circle cx="6" cy="18" r="3" stroke={c} strokeWidth="1.6" />
      <path d="M9 8l12 8M9 16l12-8" stroke={c} strokeWidth="1.6" strokeLinecap="round" />
    </svg>,

  broom: (c = "#141414", s = 22) =>
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M15 3l6 6-9 9H6v-6l9-9Z" stroke={c} strokeWidth="1.6" strokeLinejoin="round" />
      <path d="M6 21l3-3" stroke={c} strokeWidth="1.6" strokeLinecap="round" />
    </svg>

};

// ─── Ambient home illustration (subtle behind input)
function AmbientHomes({ opacity = .35 }) {
  // soft warm gradient with simple roof silhouettes
  return (
    <svg viewBox="0 0 320 220" style={{ width: '100%', height: 'auto', display: 'block', opacity }}>
      <defs>
        <linearGradient id="ezSky" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor="#FFE988" />
          <stop offset="100%" stopColor="#FBF8F1" />
        </linearGradient>
      </defs>
      <rect width="320" height="220" fill="url(#ezSky)" />
      {/* far hills */}
      <path d="M0 160 Q40 140 80 155 T160 150 T240 155 T320 145 V220 H0 Z" fill="#F4EFE2" />
      {/* houses row */}
      <g fill="#141414" opacity=".18">
        <path d="M30 175 L30 200 L70 200 L70 175 L60 165 L50 165 L50 175 Z" />
        <path d="M90 180 L90 200 L130 200 L130 180 L110 162 Z" />
        <path d="M150 178 L150 200 L195 200 L195 178 L180 160 L165 160 Z" />
        <path d="M210 180 L210 200 L255 200 L255 180 L232 158 Z" />
        <path d="M270 178 L270 200 L315 200 L315 178 L305 168 L290 168 L290 178 Z" />
      </g>
      {/* sun */}
      <circle cx="260" cy="60" r="22" fill="#FCD24A" opacity=".6" />
      <circle cx="260" cy="60" r="14" fill="#FCD24A" opacity=".9" />
    </svg>);

}

// ─── Chip
function Chip({ icon, label, active = false, onClick }) {
  return (
    <button onClick={onClick} style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '8px 12px', borderRadius: 999, whiteSpace: 'nowrap',
      background: active ? 'var(--ez-ink)' : '#fff',
      color: active ? '#fff' : 'var(--ez-ink)',
      border: active ? '1px solid var(--ez-ink)' : '1px solid var(--ez-border)',
      fontSize: 13, fontWeight: 600, letterSpacing: '-0.01em',
      boxShadow: active ? 'none' : 'var(--ez-shadow-sm)',
      flexShrink: 0
    }}>
      {icon && <span style={{ display: 'inline-flex' }}>{icon}</span>}
      {label}
    </button>);

}

// ─── Black pill button
function PillBtn({ children, onClick, variant = 'primary', full = false, style = {} }) {
  const base = {
    display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
    padding: '14px 22px', borderRadius: 999, fontWeight: 700, fontSize: 15,
    letterSpacing: '-0.01em', width: full ? '100%' : 'auto', cursor: 'pointer',
    transition: 'transform .12s ease, box-shadow .15s ease'
  };
  const variants = {
    primary: { background: 'var(--ez-ink)', color: '#fff', boxShadow: '0 6px 16px rgba(20,20,20,.18)' },
    yellow: { background: 'var(--ez-yellow)', color: 'var(--ez-ink)', boxShadow: '0 6px 18px rgba(252,210,74,.4)' },
    ghost: { background: 'transparent', color: 'var(--ez-ink)', border: '1px solid var(--ez-border)' },
    soft: { background: '#fff', color: 'var(--ez-ink)', border: '1px solid var(--ez-border)' }
  };
  return (
    <button onClick={onClick} style={{ ...base, ...variants[variant], ...style }}>
      {children}
    </button>);

}

Object.assign(window, { EZLogo, EZMark, EZLogoImg, Icon, Chip, PillBtn, AmbientHomes });