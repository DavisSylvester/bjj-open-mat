// tokens-sport.jsx — Sports Ticker / Scoreboard tokens & primitives.
// Dark navy, uppercase condensed type, color-coded stat bars, sharp edges,
// no decorative shadows or glass. Information-density first. Reuses the
// shared Icon component + SESSIONS data from tokens.jsx — load tokens.jsx
// first so Icon, GiBadge, ExpBadge, BeltBadge, SESSIONS are global.

const SP = {
  // Surfaces — deep navy stadium
  bg:        '#070C1F',          // canvas
  bg2:       '#0B1330',          // raised plane
  surface:   '#101A3A',          // card
  surfaceHi: '#16244A',          // active/elevated
  surfaceLo: '#080F26',          // recessed (ticker base)
  border:    '#1B2A52',          // primary divider
  borderHi:  '#2A3D6B',          // emphasized divider

  // Type
  text:    '#FFFFFF',
  body:    '#C7D3F0',
  muted:   '#7286B0',
  faint:   '#3F5085',

  // Brand + status
  red:     '#FF2244',            // primary CTA / live
  redDeep: '#B30E29',
  amber:   '#FFC107',            // alert / score
  green:   '#00E599',            // success / live-on
  greenDeep:'#00A36E',

  // Category colors — punchier scoreboard values
  gi:      '#2196F3',
  noGi:    '#FF9800',
  both:    '#B061FF',

  // Experience
  allLevels:   '#00E599',
  beginner:    '#3DDC84',
  intermediate:'#FFC107',
  advanced:    '#FF2244',

  // Type families
  display: '"Barlow Condensed", "Oswald", Impact, sans-serif',
  mono:    '"JetBrains Mono", "Roboto Mono", "Barlow", monospace',
  body_f:  '"Barlow", -apple-system, system-ui, sans-serif',
};

if (typeof document !== 'undefined' && !document.getElementById('sp-styles')) {
  const s = document.createElement('style');
  s.id = 'sp-styles';
  s.textContent = `
    .sp-display { font-family: ${SP.display}; font-weight: 700; letter-spacing: 0.02em; text-transform: uppercase; line-height: 0.95; }
    .sp-h1      { font-family: ${SP.display}; font-weight: 800; font-size: 32px; letter-spacing: 0.01em; line-height: 0.95; text-transform: uppercase; }
    .sp-h2      { font-family: ${SP.display}; font-weight: 700; font-size: 18px; letter-spacing: 0.05em; text-transform: uppercase; line-height: 1; }
    .sp-label   { font-family: ${SP.display}; font-weight: 700; font-size: 10px; letter-spacing: 0.18em; text-transform: uppercase; }
    .sp-mini    { font-family: ${SP.display}; font-weight: 700; font-size: 9px; letter-spacing: 0.16em; text-transform: uppercase; }
    .sp-num     { font-family: ${SP.display}; font-weight: 800; font-variant-numeric: tabular-nums; line-height: 1; letter-spacing: 0; }
    .sp-body    { font-family: ${SP.body_f}; font-weight: 500; font-size: 13px; line-height: 1.45; }

    .sp-scroll::-webkit-scrollbar { display: none; }
    .sp-scroll { scrollbar-width: none; }

    @keyframes sp-live-pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50%      { opacity: 0.4; transform: scale(0.7); }
    }
    .sp-live-dot { animation: sp-live-pulse 1.2s ease-in-out infinite; }

    @keyframes sp-ticker {
      from { transform: translateX(0); }
      to   { transform: translateX(-50%); }
    }
  `;
  document.head.appendChild(s);
}

// ─────────────────────────────────────────────────────────────
// Section header: vertical color bar + uppercase title + meta on right
// ─────────────────────────────────────────────────────────────
const SpSectionHead = ({ accent = SP.red, title, meta, sub }) => (
  <div style={{
    display: 'flex', alignItems: 'center', gap: 10,
    paddingBottom: 8,
    borderBottom: `1px solid ${SP.border}`,
  }}>
    <div style={{ width: 4, height: 22, background: accent, marginRight: 2 }} />
    <div className="sp-h2" style={{ color: SP.text, fontSize: 15 }}>{title}</div>
    {sub && <span className="sp-mini" style={{ color: SP.muted }}>{sub}</span>}
    <div style={{ flex: 1 }} />
    {meta && <span className="sp-mini" style={{ color: SP.muted }}>{meta}</span>}
  </div>
);

// ─────────────────────────────────────────────────────────────
// Live dot
// ─────────────────────────────────────────────────────────────
const SpLive = ({ color = SP.red, label = 'Live', size = 7 }) => (
  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
    <span className="sp-live-dot" style={{ width: size, height: size, borderRadius: 99, background: color, boxShadow: `0 0 8px ${color}` }} />
    <span className="sp-mini" style={{ color, fontSize: 9 }}>{label}</span>
  </span>
);

// ─────────────────────────────────────────────────────────────
// Stat Bar — horizontal gauge. value 0-1, with label + numeric on right.
// ─────────────────────────────────────────────────────────────
const SpStatBar = ({ label, value, max = 5, color = SP.red, suffix }) => {
  const pct = Math.min(1, value / max);
  return (
    <div style={{ padding: '8px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 5 }}>
        <span className="sp-mini" style={{ color: SP.body, fontSize: 10 }}>{label}</span>
        <span style={{ display: 'inline-flex', alignItems: 'baseline', gap: 2 }}>
          <span className="sp-num" style={{ color: SP.text, fontSize: 14 }}>{typeof value === 'number' ? value.toFixed(1) : value}</span>
          {suffix && <span className="sp-mini" style={{ color: SP.muted }}>{suffix}</span>}
        </span>
      </div>
      <div style={{ height: 5, background: SP.surfaceLo, position: 'relative', overflow: 'hidden' }}>
        {/* 5-tick scale */}
        {Array.from({ length: max - 1 }).map((_, i) => (
          <div key={i} style={{ position: 'absolute', top: 0, bottom: 0, left: `${((i + 1) / max) * 100}%`, width: 1, background: SP.bg, zIndex: 2 }} />
        ))}
        <div style={{ height: '100%', width: `${pct * 100}%`, background: color, position: 'relative' }} />
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Scoreboard data cell: label on top, big tabular value
// ─────────────────────────────────────────────────────────────
const SpCell = ({ label, value, suffix, color = SP.text, sub, accent }) => (
  <div style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 4, marginBottom: 4 }}>
      {accent && <div style={{ width: 6, height: 6, background: accent }} />}
      <span className="sp-mini" style={{ color: SP.muted, fontSize: 9 }}>{label}</span>
    </div>
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 3 }}>
      <span className="sp-num" style={{ color, fontSize: 26 }}>{value}</span>
      {suffix && <span className="sp-num" style={{ color: SP.muted, fontSize: 12 }}>{suffix}</span>}
    </div>
    {sub && <span className="sp-mini" style={{ color: SP.faint, marginTop: 2 }}>{sub}</span>}
  </div>
);

// ─────────────────────────────────────────────────────────────
// Gi Type bar — flat, sharp-edged. Replaces glass GiBadge.
// ─────────────────────────────────────────────────────────────
const SpGiTag = ({ type = 'gi', size = 'md' }) => {
  const m = {
    gi:   { color: SP.gi,   label: 'Gi' },
    nogi: { color: SP.noGi, label: 'No-Gi' },
    both: { color: SP.both, label: 'Gi+No-Gi' },
  }[type];
  const sm = size === 'sm';
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: sm ? '3px 7px 3px 5px' : '4px 9px 4px 6px',
      background: m.color + '1C',
      borderLeft: `2px solid ${m.color}`,
      fontFamily: SP.display, fontWeight: 800, fontSize: sm ? 9 : 11,
      letterSpacing: 0.12, textTransform: 'uppercase',
      color: m.color, lineHeight: 1,
    }}>
      {m.label}
    </span>
  );
};

// ─────────────────────────────────────────────────────────────
// Exp tag — same flat treatment
// ─────────────────────────────────────────────────────────────
const SpExpTag = ({ level = 'all', size = 'md' }) => {
  const m = {
    all: { color: SP.allLevels, label: 'All Lv' },
    beg: { color: SP.beginner,  label: 'Begin' },
    int: { color: SP.intermediate, label: 'Inter' },
    adv: { color: SP.advanced,  label: 'Adv' },
  }[level];
  const sm = size === 'sm';
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4,
      padding: sm ? '3px 7px' : '4px 9px',
      background: m.color + '1C',
      borderLeft: `2px solid ${m.color}`,
      fontFamily: SP.display, fontWeight: 800, fontSize: sm ? 9 : 11,
      letterSpacing: 0.12, textTransform: 'uppercase',
      color: m.color, lineHeight: 1,
    }}>
      {m.label}
    </span>
  );
};

// ─────────────────────────────────────────────────────────────
// Belt rank bar (sport flavor — solid block + stripes, sharp edge)
// ─────────────────────────────────────────────────────────────
const SpBelt = ({ belt = 'blue', stripes = 0 }) => {
  const colors = {
    white:  { bg: '#E5E5E5', fg: '#0B1330' },
    blue:   { bg: '#1E5BC9', fg: '#fff' },
    purple: { bg: '#7A2BB5', fg: '#fff' },
    brown:  { bg: '#6B3A1A', fg: '#fff' },
    black:  { bg: '#0A0A0A', fg: '#fff' },
  }[belt];
  return (
    <span style={{ display: 'inline-flex', alignItems: 'stretch', height: 16 }}>
      <span style={{
        background: colors.bg, color: colors.fg,
        fontFamily: SP.display, fontWeight: 800, fontSize: 9, letterSpacing: 0.16,
        textTransform: 'uppercase',
        display: 'inline-flex', alignItems: 'center',
        padding: '0 8px',
      }}>{belt}</span>
      <span style={{ width: 14, background: '#000', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 1 }}>
        {Array.from({ length: stripes }).map((_, i) => (
          <span key={i} style={{ width: 2, height: 10, background: '#fff' }} />
        ))}
      </span>
    </span>
  );
};

// ─────────────────────────────────────────────────────────────
// Session row — high-density scoreboard row (replaces SessionCard)
// ─────────────────────────────────────────────────────────────
const SpSessionRow = ({ session, live = false }) => {
  const accent = { gi: SP.gi, nogi: SP.noGi, both: SP.both }[session.gi];
  return (
    <div style={{
      position: 'relative',
      background: SP.surface,
      borderLeft: `3px solid ${accent}`,
      padding: '11px 12px 11px 11px',
      display: 'grid',
      gridTemplateColumns: 'auto 1fr auto',
      gap: 10,
      alignItems: 'center',
    }}>
      {/* time column */}
      <div style={{ minWidth: 54, borderRight: `1px solid ${SP.border}`, paddingRight: 10 }}>
        <div className="sp-mini" style={{ color: SP.muted, fontSize: 9 }}>{session.day}</div>
        <div className="sp-num" style={{ color: SP.text, fontSize: 16, marginTop: 2 }}>{session.time.split(' ')[0]}</div>
      </div>
      {/* main */}
      <div style={{ minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
          {live && <SpLive label="On Now" color={SP.green} />}
          <span className="sp-mini" style={{ color: SP.muted, fontSize: 9 }}>{session.dist}</span>
        </div>
        <div className="sp-h2" style={{ color: SP.text, fontSize: 14, letterSpacing: 0.03 }}>{session.gym}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 4, marginTop: 6 }}>
          <SpGiTag type={session.gi} size="sm" />
          <SpExpTag level={session.exp} size="sm" />
        </div>
      </div>
      {/* fee column */}
      <div style={{ textAlign: 'right' }}>
        <div className="sp-mini" style={{ color: SP.muted, fontSize: 9 }}>Mat Fee</div>
        <div className="sp-num" style={{
          color: session.fee === 0 ? SP.green : SP.text,
          fontSize: 22,
          marginTop: 2,
        }}>{session.fee === 0 ? 'FREE' : `$${session.fee}`}</div>
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Primary CTA — sharp, no shadow, big tap target
// ─────────────────────────────────────────────────────────────
const SpButton = ({ children, icon, full = false, color = SP.red, onClick }) => (
  <button onClick={onClick} style={{
    width: full ? '100%' : 'auto',
    height: 54, padding: '0 22px',
    background: color, color: '#fff',
    border: 'none', cursor: 'pointer',
    fontFamily: SP.display, fontWeight: 800, fontSize: 16,
    letterSpacing: 0.14, textTransform: 'uppercase',
    display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 10,
    position: 'relative',
  }}>
    {icon && <Icon name={icon} size={18} color="#fff" strokeWidth={2.8} />}
    {children}
    {/* corner ticks */}
    <span style={{ position: 'absolute', top: 0, left: 0, width: 8, height: 8, borderTop: '2px solid rgba(255,255,255,0.5)', borderLeft: '2px solid rgba(255,255,255,0.5)' }} />
    <span style={{ position: 'absolute', bottom: 0, right: 0, width: 8, height: 8, borderBottom: '2px solid rgba(255,255,255,0.5)', borderRight: '2px solid rgba(255,255,255,0.5)' }} />
  </button>
);

// ─────────────────────────────────────────────────────────────
// Bottom nav — flat, no glass, active tab underlined yellow
// ─────────────────────────────────────────────────────────────
const SpBottomNav = ({ active = 'home' }) => {
  const tabs = [
    { id: 'home',     icon: 'home',     label: 'Feed' },
    { id: 'search',   icon: 'search',   label: 'Find' },
    { id: 'schedule', icon: 'calendar', label: 'Sched' },
    { id: 'profile',  icon: 'user',     label: 'Me' },
  ];
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 40,
      paddingBottom: 30, paddingTop: 0,
      background: SP.bg2,
      borderTop: `1px solid ${SP.borderHi}`,
    }}>
      <div style={{ display: 'flex', alignItems: 'stretch' }}>
        {tabs.map(t => {
          const on = t.id === active;
          return (
            <div key={t.id} style={{
              flex: 1, position: 'relative',
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
              padding: '11px 6px 8px',
              background: on ? SP.surface : 'transparent',
            }}>
              {on && <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 3, background: SP.amber }} />}
              <Icon name={t.icon} size={20} color={on ? SP.text : SP.muted} strokeWidth={on ? 2.5 : 2} />
              <span style={{
                fontFamily: SP.display, fontWeight: 800, fontSize: 10,
                letterSpacing: 0.16, textTransform: 'uppercase',
                color: on ? SP.text : SP.muted,
              }}>{t.label}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Scoreboard ticker (live strip at top of feed)
// ─────────────────────────────────────────────────────────────
const SpTickerStrip = ({ items }) => (
  <div style={{
    background: '#000',
    padding: '8px 0',
    overflow: 'hidden',
    borderTop: `1px solid ${SP.borderHi}`,
    borderBottom: `1px solid ${SP.borderHi}`,
    position: 'relative',
  }}>
    <div style={{ display: 'flex', gap: 24, paddingLeft: 14, whiteSpace: 'nowrap' }}>
      {items.map((it, i) => (
        <span key={i} style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
          <SpLive color={SP.green} label="Live" size={6} />
          <span className="sp-mini" style={{ color: SP.muted, fontSize: 9 }}>{it.time}</span>
          <span className="sp-h2" style={{ color: SP.text, fontSize: 12 }}>{it.gym}</span>
          <SpGiTag type={it.gi} size="sm" />
          {i < items.length - 1 && <span style={{ color: SP.borderHi, marginLeft: 8 }}>·</span>}
        </span>
      ))}
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// Map backdrop — dark stadium map, no rounded edges
// ─────────────────────────────────────────────────────────────
const SpMap = ({ height = 280, pins = [] }) => (
  <div style={{
    height, width: '100%', position: 'relative', overflow: 'hidden',
    background: SP.surfaceLo,
  }}>
    <svg width="100%" height="100%" viewBox="0 0 400 280" preserveAspectRatio="xMidYMid slice" style={{ position: 'absolute', inset: 0 }}>
      <defs>
        <pattern id="sp-grid" width="40" height="40" patternUnits="userSpaceOnUse">
          <path d="M40 0H0v40" fill="none" stroke={SP.border} strokeWidth="1"/>
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#sp-grid)" />
      <path d="M-20 70 L 420 110" stroke={SP.border} strokeWidth="8" />
      <path d="M-20 200 L 420 170" stroke={SP.border} strokeWidth="8" />
      <path d="M120 -20 L 100 300" stroke={SP.border} strokeWidth="6" />
      <path d="M260 -20 L 300 300" stroke={SP.border} strokeWidth="8" />
    </svg>
    {pins.map((p, i) => {
      const c = { gi: SP.gi, nogi: SP.noGi, both: SP.both }[p.gi];
      return (
        <div key={i} style={{
          position: 'absolute', left: `${p.x}%`, top: `${p.y}%`,
          transform: 'translate(-50%, -50%)',
          background: c, color: '#fff',
          padding: '4px 7px',
          fontFamily: SP.display, fontWeight: 800, fontSize: 11, letterSpacing: 0.1,
          textTransform: 'uppercase',
          border: '1px solid rgba(255,255,255,0.25)',
          boxShadow: p.active ? `0 0 0 2px ${c}, 0 0 18px ${c}` : 'none',
          zIndex: p.active ? 2 : 1,
        }}>
          {p.label}
        </div>
      );
    })}
  </div>
);

// ─────────────────────────────────────────────────────────────
// Page wrapper
// ─────────────────────────────────────────────────────────────
const SpPhone = ({ children, scroll = true, hasNav = true, hasStatusReserve = true }) => (
  <div className="sp-scroll" style={{
    background: SP.bg, width: '100%', height: '100%',
    color: SP.text, fontFamily: SP.body_f,
    display: 'flex', flexDirection: 'column',
    paddingTop: hasStatusReserve ? 54 : 0,
    paddingBottom: hasNav ? 86 : 0,
    overflow: scroll ? 'auto' : 'hidden',
    position: 'relative',
  }}>
    {children}
  </div>
);

Object.assign(window, {
  SP, SpSectionHead, SpLive, SpStatBar, SpCell, SpGiTag, SpExpTag, SpBelt,
  SpSessionRow, SpButton, SpBottomNav, SpTickerStrip, SpMap, SpPhone,
});
