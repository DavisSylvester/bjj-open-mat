// tokens.jsx — Design tokens and shared primitives for Open Mat BJJ app
// All UI is built on this. Loaded before screens.jsx and kit.jsx.

const OM = {
  // Brand
  crimson: '#E94560',
  crimsonHot: '#FF5A75',
  crimsonDeep: '#B6243A',
  teal: '#16C79A',
  tealDeep: '#0E8C6B',

  // Gi types
  gi: '#2196F3',         // blue
  noGi: '#FF9800',       // amber
  both: '#9C27B0',       // purple

  // Experience
  allLevels: '#16C79A',
  beginner: '#3DDC84',
  intermediate: '#FF9800',
  advanced: '#E94560',

  // Belt ranks
  belts: {
    white:  { bg: '#F5F5F5', stripe: '#1A1A2E', fg: '#1A1A2E' },
    blue:   { bg: '#1E5BC9', stripe: '#0D2E6B', fg: '#fff' },
    purple: { bg: '#6A2A9A', stripe: '#2A0D45', fg: '#fff' },
    brown:  { bg: '#6B3A1A', stripe: '#2E1808', fg: '#fff' },
    black:  { bg: '#0A0A0A', stripe: '#E94560', fg: '#fff' },
  },

  // Light glass surfaces
  // The phone bg uses bgGradient (colorful) so blurred glass surfaces have
  // something to refract. Solid bg is the warm canvas color underneath.
  bg:       '#F4F1EC',
  bgGradient: 'radial-gradient(at 18% 8%, rgba(233,69,96,0.22) 0%, transparent 48%),' +
              'radial-gradient(at 88% 78%, rgba(156,39,176,0.20) 0%, transparent 46%),' +
              'radial-gradient(at 72% 26%, rgba(22,199,154,0.16) 0%, transparent 52%),' +
              'radial-gradient(at 8% 92%, rgba(33,150,243,0.18) 0%, transparent 50%),' +
              'linear-gradient(180deg, #F8F5EF 0%, #EFEBE3 100%)',
  bgSoft:   'rgba(255,255,255,0.55)',
  surface:  'rgba(255,255,255,0.55)',          // glass card
  surfaceHi:'rgba(255,255,255,0.78)',          // elevated glass
  surfaceSolid:'#FFFFFF',                       // when blur not possible
  border:   'rgba(255,255,255,0.65)',           // top highlight
  borderHi: 'rgba(255,255,255,0.85)',
  borderDark:'rgba(20,20,40,0.07)',             // outer hairline

  text:     '#0F1430',
  body:     'rgba(15,20,48,0.75)',
  muted:    'rgba(15,20,48,0.55)',
  faint:    'rgba(15,20,48,0.35)',

  // Light variant
  l_bg:       '#F4F5F9',
  l_surface:  '#FFFFFF',
  l_border:   'rgba(20,20,40,0.08)',
  l_text:     '#0E1326',
  l_body:     'rgba(14,19,38,0.78)',
  l_muted:    'rgba(14,19,38,0.55)',

  // Type
  display: '"Barlow Condensed", "Oswald", Impact, sans-serif',
  body_f: '"Barlow", "Inter", -apple-system, system-ui, sans-serif',
};

// Reusable global CSS for the app's UI — injected once.
if (typeof document !== 'undefined' && !document.getElementById('om-styles')) {
  const s = document.createElement('style');
  s.id = 'om-styles';
  s.textContent = `
    .om-display { font-family: ${OM.display}; letter-spacing: 0.01em; font-weight: 700; line-height: 0.95; text-transform: uppercase; }
    .om-h1 { font-family: ${OM.display}; font-weight: 700; font-size: 32px; line-height: 1.0; letter-spacing: 0.01em; text-transform: uppercase; }
    .om-h2 { font-family: ${OM.display}; font-weight: 700; font-size: 22px; line-height: 1.05; letter-spacing: 0.02em; text-transform: uppercase; }
    .om-eyebrow { font-family: ${OM.display}; font-weight: 600; font-size: 12px; letter-spacing: 0.14em; text-transform: uppercase; }
    .om-body { font-family: ${OM.body_f}; font-weight: 400; font-size: 14px; line-height: 1.45; }
    .om-num { font-family: ${OM.display}; font-weight: 700; letter-spacing: 0.01em; font-variant-numeric: tabular-nums; }
    .om-mono { font-family: ${OM.body_f}; font-weight: 500; font-variant-numeric: tabular-nums; }

    .om-card {
      background: ${OM.surface};
      backdrop-filter: blur(20px) saturate(180%);
      -webkit-backdrop-filter: blur(20px) saturate(180%);
      border: 1px solid ${OM.borderDark};
      border-radius: 20px;
      box-shadow:
        inset 1.5px 1.5px 1px rgba(255,255,255,0.9),
        inset -1px -1px 1px rgba(255,255,255,0.4),
        0 1px 2px rgba(20,20,40,0.05),
        0 8px 24px rgba(20,20,40,0.06);
    }
    .om-glass {
      background: ${OM.surface};
      backdrop-filter: blur(20px) saturate(180%);
      -webkit-backdrop-filter: blur(20px) saturate(180%);
      box-shadow:
        inset 1.5px 1.5px 1px rgba(255,255,255,0.9),
        inset -1px -1px 1px rgba(255,255,255,0.4);
    }
    .om-pressable { transition: transform .12s ease, background .12s ease; }
    .om-pressable:active { transform: scale(0.98); }

    .om-scroll::-webkit-scrollbar { display: none; }
    .om-scroll { scrollbar-width: none; }

    @keyframes om-shimmer {
      0% { background-position: -200px 0; }
      100% { background-position: 200px 0; }
    }
    .om-shimmer {
      background: linear-gradient(90deg, rgba(20,20,40,0.04) 0%, rgba(20,20,40,0.10) 50%, rgba(20,20,40,0.04) 100%);
      background-size: 400px 100%;
      animation: om-shimmer 1.4s ease-in-out infinite;
    }
  `;
  document.head.appendChild(s);
}

// ─────────────────────────────────────────────────────────────
// Icons (24px, stroke 2, currentColor)
// ─────────────────────────────────────────────────────────────
const Icon = ({ name, size = 22, color = 'currentColor', strokeWidth = 2 }) => {
  const props = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: color, strokeWidth, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (name) {
    case 'home':    return <svg {...props}><path d="M3 10l9-7 9 7v10a2 2 0 01-2 2h-4v-7h-6v7H5a2 2 0 01-2-2V10z"/></svg>;
    case 'search':  return <svg {...props}><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>;
    case 'calendar':return <svg {...props}><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>;
    case 'user':    return <svg {...props}><circle cx="12" cy="8" r="4"/><path d="M4 21c1-4 4-7 8-7s7 3 8 7"/></svg>;
    case 'pin':     return <svg {...props}><path d="M12 22s7-7.5 7-13a7 7 0 10-14 0c0 5.5 7 13 7 13z"/><circle cx="12" cy="9" r="2.5"/></svg>;
    case 'filter':  return <svg {...props}><path d="M4 5h16M7 12h10M10 19h4"/></svg>;
    case 'sliders': return <svg {...props}><path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3"/><circle cx="4" cy="12" r="2"/><circle cx="12" cy="10" r="2"/><circle cx="20" cy="14" r="2"/></svg>;
    case 'gps':     return <svg {...props}><circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="8"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/></svg>;
    case 'clock':   return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>;
    case 'star':    return <svg {...props} fill="currentColor" stroke="none"><path d="M12 2l3 7 7 .8-5.3 4.8 1.6 7.2L12 18l-6.3 3.8 1.6-7.2L2 9.8 9 9z"/></svg>;
    case 'star-o':  return <svg {...props}><path d="M12 2l3 7 7 .8-5.3 4.8 1.6 7.2L12 18l-6.3 3.8 1.6-7.2L2 9.8 9 9z"/></svg>;
    case 'heart':   return <svg {...props}><path d="M12 21s-8-5-8-11a5 5 0 019-3 5 5 0 019 3c0 6-8 11-8 11h-2z"/></svg>;
    case 'heart-f': return <svg {...props} fill="currentColor" stroke="none"><path d="M12 21s-8-5-8-11a5 5 0 019-3 5 5 0 019 3c0 6-8 11-8 11z"/></svg>;
    case 'plus':    return <svg {...props}><path d="M12 5v14M5 12h14"/></svg>;
    case 'check':   return <svg {...props}><path d="M4 12l5 5L20 6"/></svg>;
    case 'arrow-l': return <svg {...props}><path d="M19 12H5M12 5l-7 7 7 7"/></svg>;
    case 'arrow-r': return <svg {...props}><path d="M5 12h14M12 5l7 7-7 7"/></svg>;
    case 'chevron-r': return <svg {...props}><path d="M9 6l6 6-6 6"/></svg>;
    case 'chevron-d': return <svg {...props}><path d="M6 9l6 6 6-6"/></svg>;
    case 'dollar':  return <svg {...props}><path d="M12 2v20M17 6H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6"/></svg>;
    case 'gift':    return <svg {...props}><rect x="3" y="9" width="18" height="12" rx="1"/><path d="M3 13h18M12 9v12M12 9c-1.5-3-5-3-5 0M12 9c1.5-3 5-3 5 0"/></svg>;
    case 'free':    return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M8 12h8M9 9l-1 3 1 3"/></svg>;
    case 'parking': return <svg {...props}><rect x="3" y="3" width="18" height="18" rx="3"/><path d="M10 17V8h3a2.5 2.5 0 010 5h-3"/></svg>;
    case 'shower':  return <svg {...props}><path d="M5 12h14M12 12V8a3 3 0 013-3h3M12 16v1M9 19v1M15 19v1M12 22v1"/></svg>;
    case 'wifi':    return <svg {...props}><path d="M2 9c5.5-5 14.5-5 20 0M5 13c3-3 11-3 14 0M8.5 17c1.5-1.5 5.5-1.5 7 0"/><circle cx="12" cy="20" r="1" fill="currentColor"/></svg>;
    case 'door':    return <svg {...props}><path d="M6 21V4a1 1 0 011-1h10a1 1 0 011 1v17M3 21h18M15 12h1"/></svg>;
    case 'shop':    return <svg {...props}><path d="M3 9l1.5-5h15L21 9M3 9v11h18V9M3 9h18M9 13h6"/></svg>;
    case 'water':   return <svg {...props}><path d="M12 2s7 7 7 13a7 7 0 11-14 0c0-6 7-13 7-13z"/></svg>;
    case 'directions': return <svg {...props}><path d="M12 2l10 10-10 10L2 12 12 2z"/><path d="M8 12h6v-2l3 3-3 3v-2H8z" fill="currentColor" stroke="none"/></svg>;
    case 'route':   return <svg {...props}><circle cx="6" cy="6" r="3"/><circle cx="18" cy="18" r="3"/><path d="M9 6h6a4 4 0 014 4v0a4 4 0 01-4 4H9a4 4 0 00-4 4v0"/></svg>;
    case 'gi':      return <svg {...props}><path d="M5 4l4-2h6l4 2-2 4-2-1v15H9V7L7 8 5 4z"/><path d="M12 7v8"/></svg>;
    case 'shirt':   return <svg {...props}><path d="M4 6l4-3h8l4 3-2 4-2-1v13H8V9L6 10 4 6z"/></svg>;
    case 'swords':  return <svg {...props}><path d="M14 5l5-3 1 1-3 5M10 19l-5 3-1-1 3-5M15 6l3 3M6 15l3 3M14 11l-3 3M11 8l-3 3M5 2l5 5M19 22l-5-5"/></svg>;
    case 'bell':    return <svg {...props}><path d="M6 8a6 6 0 0112 0c0 7 3 9 3 9H3s3-2 3-9M10 21a2 2 0 004 0"/></svg>;
    case 'settings':return <svg {...props}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 00.3 1.8l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.7 1.7 0 00-1.8-.3 1.7 1.7 0 00-1 1.5V21a2 2 0 11-4 0v-.1a1.7 1.7 0 00-1.1-1.5 1.7 1.7 0 00-1.8.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1a1.7 1.7 0 00.3-1.8 1.7 1.7 0 00-1.5-1H3a2 2 0 110-4h.1a1.7 1.7 0 001.5-1.1 1.7 1.7 0 00-.3-1.8l-.1-.1a2 2 0 112.8-2.8l.1.1a1.7 1.7 0 001.8.3H9a1.7 1.7 0 001-1.5V3a2 2 0 114 0v.1a1.7 1.7 0 001 1.5 1.7 1.7 0 001.8-.3l.1-.1a2 2 0 112.8 2.8l-.1.1a1.7 1.7 0 00-.3 1.8V9a1.7 1.7 0 001.5 1H21a2 2 0 110 4h-.1a1.7 1.7 0 00-1.5 1z"/></svg>;
    case 'moon':    return <svg {...props}><path d="M20 14a8 8 0 11-9-10 6 6 0 009 10z"/></svg>;
    case 'logout':  return <svg {...props}><path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9"/></svg>;
    case 'more':    return <svg {...props}><circle cx="5" cy="12" r="1.5" fill="currentColor"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/><circle cx="19" cy="12" r="1.5" fill="currentColor"/></svg>;
    case 'close':   return <svg {...props}><path d="M6 6l12 12M18 6L6 18"/></svg>;
    case 'phone':   return <svg {...props}><path d="M22 17v3a2 2 0 01-2 2A19 19 0 012 5a2 2 0 012-2h3a2 2 0 012 2c0 1 .2 2.1.5 3a2 2 0 01-.5 2L8 11a16 16 0 005 5l1-1a2 2 0 012-.5c1 .3 2 .5 3 .5a2 2 0 012 2z"/></svg>;
    case 'globe':   return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 010 18M12 3a14 14 0 000 18"/></svg>;
    case 'edit':    return <svg {...props}><path d="M12 20h9M16.5 3.5a2.1 2.1 0 013 3L7 19l-4 1 1-4 12.5-12.5z"/></svg>;
    case 'flame':   return <svg {...props}><path d="M12 2s5 4 5 10a5 5 0 11-10 0c0-2 1-3 1-3s0 2 2 2c2 0 2-3 2-5 0-2 0-4 0-4z"/></svg>;
    case 'medal':   return <svg {...props}><circle cx="12" cy="14" r="6"/><path d="M8 14l-3-8h14l-3 8"/></svg>;
    case 'mat':     return <svg {...props}><rect x="2" y="6" width="20" height="12" rx="1.5"/><path d="M6 6v12M18 6v12M2 12h20"/></svg>;
    default: return <svg {...props}><rect x="3" y="3" width="18" height="18" rx="3"/></svg>;
  }
};

// ─────────────────────────────────────────────────────────────
// Gi Type Badge
// ─────────────────────────────────────────────────────────────
const GiBadge = ({ type = 'gi', size = 'md', light = false }) => {
  const map = {
    gi:   { color: OM.gi,   label: 'Gi',     icon: 'gi' },
    nogi: { color: OM.noGi, label: 'No-Gi',  icon: 'shirt' },
    both: { color: OM.both, label: 'Gi + No-Gi', icon: 'swords' },
  };
  const m = map[type];
  const sm = size === 'sm';
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: sm ? '2px 8px 2px 6px' : '4px 10px 4px 7px',
      borderRadius: 999,
      background: m.color + (light ? '22' : '2A'),
      color: light ? m.color : m.color,
      border: `1px solid ${m.color}55`,
      fontFamily: OM.display, fontWeight: 700, fontSize: sm ? 10 : 11,
      letterSpacing: 0.08, textTransform: 'uppercase',
      lineHeight: 1,
    }}>
      <Icon name={m.icon} size={sm ? 11 : 13} color={m.color} strokeWidth={2.5} />
      {m.label}
    </span>
  );
};

// ─────────────────────────────────────────────────────────────
// Experience Badge
// ─────────────────────────────────────────────────────────────
const ExpBadge = ({ level = 'all', size = 'md' }) => {
  const map = {
    all: { color: OM.allLevels, label: 'All Levels' },
    beg: { color: OM.beginner,  label: 'Beginner' },
    int: { color: OM.intermediate, label: 'Intermediate' },
    adv: { color: OM.advanced,  label: 'Advanced' },
  };
  const m = map[level];
  const sm = size === 'sm';
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: sm ? '2px 8px' : '4px 10px',
      borderRadius: 999,
      background: m.color + '22',
      color: m.color,
      border: `1px solid ${m.color}44`,
      fontFamily: OM.display, fontWeight: 700, fontSize: sm ? 10 : 11,
      letterSpacing: 0.08, textTransform: 'uppercase', lineHeight: 1,
    }}>
      <span style={{ width: sm ? 5 : 6, height: sm ? 5 : 6, borderRadius: 99, background: m.color }} />
      {m.label}
    </span>
  );
};

// ─────────────────────────────────────────────────────────────
// Belt Rank Badge
// ─────────────────────────────────────────────────────────────
const BeltBadge = ({ belt = 'blue', stripes = 0, label = true, size = 'md' }) => {
  const b = OM.belts[belt];
  const sm = size === 'sm';
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'stretch',
      borderRadius: 5,
      overflow: 'hidden',
      boxShadow: '0 1px 0 rgba(255,255,255,0.06) inset, 0 2px 6px rgba(0,0,0,0.3)',
      height: sm ? 18 : 22,
    }}>
      <span style={{
        background: b.bg, color: b.fg,
        fontFamily: OM.display, fontWeight: 700,
        fontSize: sm ? 10 : 12, letterSpacing: 0.1,
        textTransform: 'uppercase',
        display: 'inline-flex', alignItems: 'center',
        padding: sm ? '0 8px' : '0 10px',
      }}>{label && (belt.charAt(0).toUpperCase() + belt.slice(1) + ' Belt')}</span>
      <span style={{ width: sm ? 12 : 16, background: b.stripe, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 1.5 }}>
        {Array.from({ length: stripes }).map((_, i) => (
          <span key={i} style={{ width: 2, height: sm ? 10 : 12, background: '#fff' }} />
        ))}
      </span>
    </span>
  );
};

// ─────────────────────────────────────────────────────────────
// Star Rating Row
// ─────────────────────────────────────────────────────────────
const StarRow = ({ label, value = 0, max = 5, interactive = false, dark = true, count, onChange }) => {
  const t = dark ? OM.text : OM.l_text;
  const m = dark ? OM.muted : OM.l_muted;
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '8px 0' }}>
      <span style={{ fontFamily: OM.body_f, fontSize: 13, color: m, fontWeight: 500 }}>{label}</span>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{ display: 'flex', gap: 2 }}>
          {Array.from({ length: max }).map((_, i) => (
            <span
              key={i}
              onClick={() => interactive && onChange && onChange(i + 1)}
              style={{ cursor: interactive ? 'pointer' : 'default', display: 'inline-flex' }}
            >
              <Icon
                name={i < Math.round(value) ? 'star' : 'star-o'}
                size={interactive ? 22 : 14}
                color={i < Math.round(value) ? '#FFC857' : (dark ? 'rgba(255,255,255,0.25)' : 'rgba(0,0,0,0.18)')}
              />
            </span>
          ))}
        </div>
        {!interactive && (
          <span className="om-num" style={{ color: t, fontSize: 13, minWidth: 28, textAlign: 'right' }}>{value.toFixed(1)}</span>
        )}
        {count !== undefined && <span className="om-mono" style={{ color: m, fontSize: 11 }}>({count})</span>}
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Session Card — horizontal card used on home + search
// ─────────────────────────────────────────────────────────────
const SessionCard = ({ session, light = false, width, compact = false }) => {
  const dark = !light;
  const text = dark ? OM.text : OM.l_text;
  const body = dark ? OM.body : OM.l_body;
  const muted = dark ? OM.muted : OM.l_muted;
  const bg = dark ? OM.surface : OM.l_surface;
  const border = dark ? OM.borderDark : OM.l_border;
  const accentBar = { gi: OM.gi, nogi: OM.noGi, both: OM.both }[session.gi];

  return (
    <div className="om-pressable" style={{
      width, background: bg, borderRadius: 18,
      border: `1px solid ${border}`,
      overflow: 'hidden', position: 'relative',
      boxShadow: '0 1px 0 rgba(255,255,255,0.7) inset, 0 1px 2px rgba(20,20,40,0.06), 0 6px 18px rgba(20,20,40,0.08)',
      cursor: 'pointer',
      backdropFilter: light ? 'none' : 'blur(20px) saturate(180%)',
      WebkitBackdropFilter: light ? 'none' : 'blur(20px) saturate(180%)',
    }}>
      {/* top accent stripe matching gi type */}
      <div style={{ height: 3, background: accentBar }} />
      <div style={{ padding: compact ? '11px 13px 12px' : '13px 14px 14px' }}>
        {/* row 1: time + distance */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <Icon name="clock" size={13} color={accentBar} strokeWidth={2.5} />
            <span className="om-num" style={{ color: text, fontSize: 14 }}>{session.time}</span>
            <span style={{ color: muted, fontFamily: OM.body_f, fontSize: 12 }}>· {session.day}</span>
          </div>
          <span style={{ color: muted, fontFamily: OM.body_f, fontSize: 11, fontWeight: 500 }}>{session.dist}</span>
        </div>
        {/* row 2: gym name */}
        <div className="om-h2" style={{ color: text, fontSize: 19, marginBottom: 8 }}>{session.gym}</div>
        {/* row 3: badges */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
          <GiBadge type={session.gi} size="sm" light={light} />
          <ExpBadge level={session.exp} size="sm" />
          <span style={{ flex: 1 }} />
          <span style={{
            display: 'inline-flex', alignItems: 'center', gap: 4,
            padding: '3px 8px', borderRadius: 999,
            background: session.fee === 0 ? OM.teal + '22' : (dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)'),
            color: session.fee === 0 ? OM.teal : (dark ? OM.body : OM.l_body),
            fontFamily: OM.display, fontWeight: 700, fontSize: 11, letterSpacing: 0.08, textTransform: 'uppercase',
          }}>
            {session.fee === 0 ? 'Free' : `$${session.fee}`}
          </span>
        </div>
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────
const EmptyState = ({ icon = 'mat', title = 'Nothing here yet', subtitle = '', cta, dark = true }) => {
  const t = dark ? OM.text : OM.l_text;
  const m = dark ? OM.muted : OM.l_muted;
  return (
    <div style={{ padding: '40px 24px', textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
      <div style={{
        width: 64, height: 64, borderRadius: 18,
        background: dark ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.04)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        marginBottom: 4,
      }}>
        <Icon name={icon} size={28} color={dark ? OM.muted : OM.l_muted} />
      </div>
      <div className="om-h2" style={{ color: t, fontSize: 17 }}>{title}</div>
      <div style={{ fontFamily: OM.body_f, fontSize: 13, color: m, maxWidth: 240, lineHeight: 1.45 }}>{subtitle}</div>
      {cta && (
        <button style={{
          marginTop: 10, padding: '10px 18px', borderRadius: 999,
          background: OM.crimson, color: '#fff', border: 'none',
          fontFamily: OM.display, fontWeight: 700, fontSize: 13, letterSpacing: 0.1, textTransform: 'uppercase',
          cursor: 'pointer',
        }}>{cta}</button>
      )}
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Shimmer Card
// ─────────────────────────────────────────────────────────────
const ShimmerCard = ({ light = false }) => {
  const dark = !light;
  const bg = dark ? OM.surface : OM.l_surface;
  const border = dark ? OM.borderDark : OM.l_border;
  return (
    <div style={{
      background: bg, borderRadius: 18, padding: '13px 14px 14px',
      border: `1px solid ${border}`,
    }}>
      <div style={{ height: 3, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)', borderRadius: 2, marginBottom: 10, width: '40%' }} />
      <div className="om-shimmer" style={{ height: 10, width: '55%', borderRadius: 5, marginBottom: 10 }} />
      <div className="om-shimmer" style={{ height: 16, width: '85%', borderRadius: 6, marginBottom: 12 }} />
      <div style={{ display: 'flex', gap: 6 }}>
        <div className="om-shimmer" style={{ height: 18, width: 60, borderRadius: 999 }} />
        <div className="om-shimmer" style={{ height: 18, width: 78, borderRadius: 999 }} />
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Primary CTA
// ─────────────────────────────────────────────────────────────
const PrimaryBtn = ({ children, full = false, icon, danger = false, color, onClick }) => (
  <button onClick={onClick} className="om-pressable" style={{
    width: full ? '100%' : 'auto',
    height: 52, padding: '0 22px',
    borderRadius: 16, border: 'none', cursor: 'pointer',
    background: color || OM.crimson, color: '#fff',
    fontFamily: OM.display, fontWeight: 700, fontSize: 16,
    letterSpacing: 0.1, textTransform: 'uppercase',
    boxShadow: `0 1px 0 rgba(255,255,255,0.18) inset, 0 -2px 0 rgba(0,0,0,0.18) inset, 0 6px 18px ${color || OM.crimson}55`,
    display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
  }}>
    {icon && <Icon name={icon} size={18} color="#fff" strokeWidth={2.5} />}
    {children}
  </button>
);

const SecondaryBtn = ({ children, icon, full = false, dark = true, onClick }) => (
  <button onClick={onClick} className="om-pressable" style={{
    width: full ? '100%' : 'auto',
    height: 44, padding: '0 16px',
    borderRadius: 14, cursor: 'pointer',
    background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)',
    color: dark ? OM.text : OM.l_text,
    border: `1px solid ${dark ? OM.borderDark : OM.l_border}`,
    fontFamily: OM.display, fontWeight: 700, fontSize: 13,
    letterSpacing: 0.08, textTransform: 'uppercase',
    display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 6,
  }}>
    {icon && <Icon name={icon} size={15} strokeWidth={2.5} />}
    {children}
  </button>
);

// ─────────────────────────────────────────────────────────────
// Bottom Nav (light glass)
// ─────────────────────────────────────────────────────────────
const BottomNav = ({ active = 'home' }) => {
  const tabs = [
    { id: 'home',     icon: 'home',     label: 'Home' },
    { id: 'search',   icon: 'search',   label: 'Search' },
    { id: 'schedule', icon: 'calendar', label: 'Schedule' },
    { id: 'profile',  icon: 'user',     label: 'Profile' },
  ];
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 40,
      paddingBottom: 30, paddingTop: 10,
      background: 'rgba(255,255,255,0.55)',
      backdropFilter: 'blur(28px) saturate(180%)',
      WebkitBackdropFilter: 'blur(28px) saturate(180%)',
      borderTop: `1px solid ${OM.borderDark}`,
      boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.9), 0 -8px 24px rgba(20,20,40,0.04)',
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-around', alignItems: 'center', padding: '0 12px' }}>
        {tabs.map(t => {
          const on = t.id === active;
          return (
            <div key={t.id} style={{
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
              padding: '6px 12px', borderRadius: 14,
              background: on ? OM.crimson + '18' : 'transparent',
            }}>
              <Icon name={t.icon} size={22} color={on ? OM.crimson : OM.muted} strokeWidth={on ? 2.5 : 2} />
              <span style={{
                fontFamily: OM.display, fontWeight: 700, fontSize: 10,
                letterSpacing: 0.12, textTransform: 'uppercase',
                color: on ? OM.crimson : OM.muted,
              }}>{t.label}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Map Backdrop — light pastel map
// ─────────────────────────────────────────────────────────────
const MapBackdrop = ({ height = 380, pins = [] }) => (
  <div style={{
    height, width: '100%', position: 'relative', overflow: 'hidden',
    background: 'radial-gradient(ellipse at 30% 20%, #FFFFFF 0%, #EDE9DF 65%, #E2DCCD 100%)',
  }}>
    {/* faint street grid */}
    <svg width="100%" height="100%" viewBox="0 0 400 380" preserveAspectRatio="xMidYMid slice" style={{ position: 'absolute', inset: 0 }}>
      <defs>
        <pattern id="om-grid" width="60" height="60" patternUnits="userSpaceOnUse">
          <path d="M60 0H0v60" fill="none" stroke="rgba(20,20,40,0.06)" strokeWidth="1"/>
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#om-grid)" />
      {/* roads */}
      <path d="M-20 90 L 420 130" stroke="#FFFFFF" strokeWidth="7" />
      <path d="M-20 240 L 420 200" stroke="#FFFFFF" strokeWidth="7" />
      <path d="M-20 340 L 420 320" stroke="#FFFFFF" strokeWidth="5" />
      <path d="M120 -20 L 100 400" stroke="#FFFFFF" strokeWidth="6" />
      <path d="M260 -20 L 300 400" stroke="#FFFFFF" strokeWidth="7" />
      {/* road outlines */}
      <path d="M-20 90 L 420 130" stroke="rgba(20,20,40,0.05)" strokeWidth="9" fill="none" opacity="0.4"/>
      {/* parks */}
      <rect x="40" y="160" width="80" height="60" fill="#C8E6C9" rx="6" />
      <rect x="290" y="240" width="70" height="70" fill="#C8E6C9" rx="6" />
      {/* water */}
      <path d="M-20 280 Q 60 260 140 290 T 320 280 L 420 300 L 420 400 L -20 400 Z" fill="#BBDEFB" opacity="0.7" />
    </svg>
    {/* pins */}
    {pins.map((p, i) => (
      <div key={i} style={{
        position: 'absolute', left: `${p.x}%`, top: `${p.y}%`,
        transform: 'translate(-50%, -100%)',
      }}>
        <div style={{
          width: p.active ? 44 : 36, height: p.active ? 44 : 36, borderRadius: 99,
          background: { gi: OM.gi, nogi: OM.noGi, both: OM.both }[p.gi],
          border: '3px solid #fff',
          boxShadow: '0 4px 14px rgba(20,20,40,0.35)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icon name={{ gi: 'gi', nogi: 'shirt', both: 'swords' }[p.gi]} size={p.active ? 22 : 18} color="#fff" strokeWidth={2.5} />
        </div>
        <div style={{
          width: 0, height: 0, marginLeft: p.active ? 16 : 12, marginTop: -3,
          borderLeft: '6px solid transparent', borderRight: '6px solid transparent',
          borderTop: `8px solid ${{ gi: OM.gi, nogi: OM.noGi, both: OM.both }[p.gi]}`,
          filter: 'drop-shadow(0 2px 2px rgba(20,20,40,0.25))',
        }} />
      </div>
    ))}
  </div>
);

// Mock data
const SESSIONS = [
  { id: 1, gym: 'Atos HQ',         time: '7:00 – 9:00 PM', day: 'Today',     dist: '1.2 mi', gi: 'gi',   exp: 'all', fee: 0 },
  { id: 2, gym: 'Gracie Barra DTLA', time: '10:00 – 12:00 PM', day: 'Sat',  dist: '2.4 mi', gi: 'nogi', exp: 'int', fee: 15 },
  { id: 3, gym: '10th Planet Rosemead', time: '12:00 – 2:00 PM', day: 'Sun',   dist: '4.1 mi', gi: 'both', exp: 'all', fee: 10 },
  { id: 4, gym: 'CheckMat South Bay', time: '6:00 – 8:00 PM', day: 'Mon',   dist: '3.8 mi', gi: 'gi',   exp: 'beg', fee: 0 },
  { id: 5, gym: 'Renzo Gracie Westwood', time: '11:00 – 1:00 PM', day: 'Sat',  dist: '5.2 mi', gi: 'nogi', exp: 'adv', fee: 20 },
];

Object.assign(window, {
  OM, Icon, GiBadge, ExpBadge, BeltBadge, StarRow, SessionCard,
  EmptyState, ShimmerCard, PrimaryBtn, SecondaryBtn, BottomNav,
  MapBackdrop, SESSIONS,
});
