// screens-sport.jsx — 8 screens in Sports Ticker / scoreboard style.
// Dense, uppercase, color-coded. No glass, no decorative shadows.
// Requires tokens.jsx (Icon, SESSIONS) and tokens-sport.jsx loaded first.

// ─────────────────────────────────────────────────────────────
// 1. HOME — live feed + ticker + scoreboard
// ─────────────────────────────────────────────────────────────
const SpHome = () => {
  const tickerItems = [
    { time: '7:00 PM', gym: 'Atos HQ',          gi: 'gi' },
    { time: '8:00 PM', gym: 'Renzo Westwood',   gi: 'nogi' },
    { time: '8:30 PM', gym: '10P Rosemead',     gi: 'both' },
  ];
  const pins = [
    { x: 24, y: 36, gi: 'gi',   label: 'ATOS' },
    { x: 56, y: 28, gi: 'both', label: '10P', active: true },
    { x: 78, y: 52, gi: 'nogi', label: 'RNZ' },
    { x: 38, y: 70, gi: 'gi',   label: 'GB' },
    { x: 70, y: 80, gi: 'nogi', label: 'CKM' },
  ];

  return (
    <SpPhone hasNav={true}>
      {/* MASTHEAD */}
      <div style={{
        padding: '4px 14px 10px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        background: SP.bg2, borderBottom: `1px solid ${SP.border}`,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 4, height: 22, background: SP.red }} />
          <div className="sp-display" style={{ fontSize: 22, color: SP.text }}>Open Mat</div>
          <span className="sp-mini" style={{ color: SP.muted, paddingLeft: 4 }}>LA / Mon Jun 2</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <Icon name="bell" size={18} color={SP.muted} />
          <Icon name="search" size={18} color={SP.muted} />
        </div>
      </div>

      {/* LIVE TICKER */}
      <SpTickerStrip items={tickerItems} />

      {/* QUICK STATS STRIP */}
      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)',
        background: SP.surfaceLo,
        borderBottom: `1px solid ${SP.border}`,
        padding: '12px 14px',
      }}>
        <SpCell label="OPEN NOW" value="3"  accent={SP.green} />
        <SpCell label="TONIGHT"  value="8"  sub="≤9 PM" />
        <SpCell label="THIS WK"  value="34" />
        <SpCell label="NEAREST"  value="0.8" suffix="mi" />
      </div>

      {/* MAP */}
      <div style={{ position: 'relative' }}>
        <SpMap height={220} pins={pins} />
        {/* corner overlay */}
        <div style={{
          position: 'absolute', top: 10, left: 14,
          background: SP.bg, padding: '5px 9px',
          borderLeft: `2px solid ${SP.red}`,
          display: 'flex', alignItems: 'center', gap: 6,
        }}>
          <SpLive color={SP.green} label="" size={6} />
          <span className="sp-mini" style={{ color: SP.text, fontSize: 9 }}>5 Mats Mapped</span>
        </div>
        <div style={{
          position: 'absolute', top: 10, right: 14,
          background: SP.bg, padding: '5px 9px',
          borderLeft: `2px solid ${SP.amber}`,
        }}>
          <span className="sp-mini" style={{ color: SP.amber, fontSize: 9 }}>10 mi · Filter</span>
        </div>
      </div>

      {/* FEED SECTION HEADER */}
      <div style={{ padding: '14px 14px 8px' }}>
        <SpSectionHead accent={SP.red} title="Tonight's Schedule" meta="LIVE & UPCOMING" sub="08 GAMES" />
      </div>

      {/* SESSION ROWS — high density */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 1, background: SP.border, marginBottom: 12 }}>
        <SpSessionRow session={SESSIONS[0]} live />
        <SpSessionRow session={SESSIONS[1]} />
        <SpSessionRow session={SESSIONS[2]} />
        <SpSessionRow session={SESSIONS[3]} />
      </div>

      <SpBottomNav active="home" />
    </SpPhone>
  );
};

// ─────────────────────────────────────────────────────────────
// 2. SEARCH & FILTER
// ─────────────────────────────────────────────────────────────
const SpSearch = () => {
  const filters = [
    { label: 'GI',         color: SP.gi,     on: true },
    { label: 'NO-GI',      color: SP.noGi,   on: false },
    { label: 'GI+NO-GI',   color: SP.both,   on: true },
    { label: 'FREE',       color: SP.green,  on: true },
    { label: 'ALL LV',     color: SP.allLevels, on: false },
    { label: 'BEGINNER',   color: SP.beginner,  on: false },
  ];
  return (
    <SpPhone>
      {/* MASTHEAD */}
      <div style={{
        padding: '4px 14px 10px',
        display: 'flex', alignItems: 'center', gap: 10,
        background: SP.bg2, borderBottom: `1px solid ${SP.border}`,
      }}>
        <Icon name="arrow-l" size={18} color={SP.text} strokeWidth={2.5} />
        <div className="sp-display" style={{ fontSize: 18, color: SP.text }}>Find Open Mats</div>
      </div>

      {/* LOCATION FIELD */}
      <div style={{
        margin: '14px 14px 12px',
        background: SP.surface,
        borderLeft: `3px solid ${SP.red}`,
        padding: '10px 12px',
        display: 'flex', alignItems: 'center', gap: 10,
      }}>
        <Icon name="pin" size={16} color={SP.red} strokeWidth={2.5} />
        <div style={{ flex: 1 }}>
          <div className="sp-mini" style={{ color: SP.muted, fontSize: 9 }}>Searching Within</div>
          <div className="sp-h2" style={{ color: SP.text, fontSize: 14, marginTop: 2 }}>Los Angeles, CA</div>
        </div>
        <div style={{
          padding: '6px 9px', background: SP.surfaceHi,
          borderLeft: `2px solid ${SP.amber}`,
          display: 'flex', alignItems: 'center', gap: 4,
        }}>
          <Icon name="gps" size={13} color={SP.amber} strokeWidth={2.5} />
          <span className="sp-mini" style={{ color: SP.amber, fontSize: 9 }}>GPS</span>
        </div>
      </div>

      {/* FILTER CHIPS */}
      <div style={{ padding: '0 14px 12px' }}>
        <div className="sp-mini" style={{ color: SP.muted, marginBottom: 6 }}>Filters · 3 Active</div>
        <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
          {filters.map((f, i) => (
            <span key={i} style={{
              padding: '6px 10px',
              background: f.on ? f.color + '24' : SP.surface,
              borderLeft: `2px solid ${f.on ? f.color : SP.borderHi}`,
              color: f.on ? f.color : SP.muted,
              fontFamily: SP.display, fontWeight: 800, fontSize: 11,
              letterSpacing: 0.14, textTransform: 'uppercase',
              display: 'inline-flex', alignItems: 'center', gap: 5,
            }}>
              {f.on && <span style={{ width: 5, height: 5, background: f.color }} />}
              {f.label}
            </span>
          ))}
        </div>
      </div>

      {/* DATE + DISTANCE GRID */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 1, background: SP.border, margin: '0 14px 14px' }}>
        <div style={{ background: SP.surface, padding: '11px 12px' }}>
          <div className="sp-mini" style={{ color: SP.muted, fontSize: 9 }}>Window</div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 4 }}>
            <span className="sp-num" style={{ color: SP.text, fontSize: 20 }}>SAT-SUN</span>
          </div>
          <div className="sp-mini" style={{ color: SP.faint, marginTop: 4 }}>Jun 7 – 8</div>
        </div>
        <div style={{ background: SP.surface, padding: '11px 12px' }}>
          <div className="sp-mini" style={{ color: SP.muted, fontSize: 9 }}>Radius</div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 3, marginTop: 4 }}>
            <span className="sp-num" style={{ color: SP.amber, fontSize: 22 }}>8</span>
            <span className="sp-num" style={{ color: SP.muted, fontSize: 12 }}>MI</span>
          </div>
          <div style={{ height: 3, background: SP.surfaceLo, marginTop: 6, position: 'relative' }}>
            <div style={{ height: '100%', width: '40%', background: SP.amber }} />
          </div>
        </div>
      </div>

      {/* RESULTS HEADER */}
      <div style={{ padding: '0 14px 8px' }}>
        <SpSectionHead
          accent={SP.green}
          title="Results"
          meta="MAP / LIST"
          sub={<><span style={{ color: SP.green, fontWeight: 800 }}>12</span> sessions</>}
        />
      </div>

      {/* RESULTS LIST */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 1, background: SP.border }}>
        {SESSIONS.slice(0, 5).map((s, i) => <SpSessionRow key={s.id} session={s} live={i === 0} />)}
      </div>

      <SpBottomNav active="search" />
    </SpPhone>
  );
};

// ─────────────────────────────────────────────────────────────
// 3. OPEN MAT DETAIL — full scoreboard
// ─────────────────────────────────────────────────────────────
const SpDetail = () => {
  const reviews = [
    { name: 'Marcus T.', belt: 'purple', stripes: 2, rating: 5, when: 'Jun 1', text: 'Great rolls. Spotless mats. Welcoming.' },
    { name: 'Jenna K.',  belt: 'blue',   stripes: 4, rating: 4, when: 'May 26', text: 'Good mix of belts. Wish it ran longer.' },
  ];
  return (
    <SpPhone hasNav={false}>
      {/* MASTHEAD */}
      <div style={{
        padding: '4px 14px 10px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        background: SP.bg2, borderBottom: `1px solid ${SP.border}`,
      }}>
        <Icon name="arrow-l" size={18} color={SP.text} strokeWidth={2.5} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <Icon name="heart" size={17} color={SP.muted} />
          <Icon name="more" size={20} color={SP.muted} />
        </div>
      </div>

      {/* SCOREBOARD HERO */}
      <div style={{ background: SP.bg2, borderBottom: `1px solid ${SP.border}` }}>
        <div style={{ padding: '14px 14px 12px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
            <SpLive color={SP.green} label="Tonight" />
            <span style={{ width: 4, height: 4, background: SP.muted, marginTop: 1 }} />
            <span className="sp-mini" style={{ color: SP.muted }}>Open Mat · Drop-in</span>
          </div>
          <div className="sp-h1" style={{ color: SP.text, fontSize: 30 }}>10th Planet</div>
          <div className="sp-display" style={{ color: SP.both, fontSize: 18, marginTop: 2 }}>Rosemead</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 8 }}>
            <SpGiTag type="both" />
            <SpExpTag level="all" />
            <span className="sp-mini" style={{ color: SP.muted, marginLeft: 4 }}>· 4.1 mi · 12 attending</span>
          </div>
        </div>

        {/* SCOREBOARD STAT STRIP */}
        <div style={{
          display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)',
          background: SP.surfaceLo,
          borderTop: `1px solid ${SP.border}`,
          padding: '12px 14px',
        }}>
          <SpCell label="DATE"   value="JUN 8" />
          <SpCell label="START"  value="12:00" suffix="PM" />
          <SpCell label="END"    value="14:00" suffix="PM" />
          <SpCell label="FEE"    value="$10"  color={SP.amber} accent={SP.amber} />
        </div>
      </div>

      {/* ADDRESS BAR */}
      <div style={{
        display: 'grid', gridTemplateColumns: '1fr auto auto', gap: 1,
        background: SP.border,
      }}>
        <div style={{ background: SP.surface, padding: '12px 14px' }}>
          <div className="sp-mini" style={{ color: SP.muted, fontSize: 9 }}>Venue</div>
          <div className="sp-h2" style={{ color: SP.text, fontSize: 13, marginTop: 3 }}>3851 Rosemead Blvd</div>
        </div>
        <button style={{
          background: SP.surfaceHi, color: SP.text, border: 'none', cursor: 'pointer',
          padding: '0 14px', fontFamily: SP.display, fontWeight: 800, fontSize: 11,
          letterSpacing: 0.14, textTransform: 'uppercase',
          display: 'inline-flex', alignItems: 'center', gap: 5,
        }}>
          <Icon name="directions" size={14} color={SP.amber} strokeWidth={2.5} />
          Map
        </button>
        <button style={{
          background: SP.surfaceHi, color: SP.text, border: 'none', cursor: 'pointer',
          padding: '0 14px', fontFamily: SP.display, fontWeight: 800, fontSize: 11,
          letterSpacing: 0.14, textTransform: 'uppercase',
          display: 'inline-flex', alignItems: 'center', gap: 5,
        }}>
          <Icon name="route" size={14} color={SP.gi} strokeWidth={2.5} />
          Waze
        </button>
      </div>

      {/* CTA */}
      <div style={{ padding: '14px' }}>
        <SpButton full icon="check">Check In</SpButton>
      </div>

      {/* STAT SHEET — ratings */}
      <div style={{ padding: '0 14px 14px' }}>
        <SpSectionHead
          accent={SP.amber}
          title="Stat Sheet"
          meta="84 REVIEWS"
          sub={<><span style={{ color: SP.amber }}>4.7</span> / 5.0 AGG</>}
        />
        <div style={{ background: SP.surface, padding: '4px 14px', marginTop: 0 }}>
          <SpStatBar label="GYM QUALITY"      value={4.8} color={SP.green} />
          <SpStatBar label="EXP LEVEL MATCH"  value={4.5} color={SP.amber} />
          <SpStatBar label="CLEANLINESS"      value={4.9} color={SP.green} />
          <SpStatBar label="FRIENDLINESS"     value={4.7} color={SP.green} />
        </div>
      </div>

      {/* REVIEWS */}
      <div style={{ padding: '0 14px 22px' }}>
        <SpSectionHead accent={SP.muted} title="Player Notes" meta="RECENT" />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 1, background: SP.border, marginTop: 0 }}>
          {reviews.map((r, i) => (
            <div key={i} style={{ background: SP.surface, padding: '11px 12px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                <span className="sp-h2" style={{ color: SP.text, fontSize: 13 }}>{r.name}</span>
                <SpBelt belt={r.belt} stripes={r.stripes} />
                <div style={{ flex: 1 }} />
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 3 }}>
                  <span className="sp-num" style={{ color: SP.amber, fontSize: 14 }}>{r.rating}.0</span>
                  <span className="sp-mini" style={{ color: SP.faint, fontSize: 9 }}>/5</span>
                </div>
                <span className="sp-mini" style={{ color: SP.muted, marginLeft: 6 }}>{r.when}</span>
              </div>
              <div className="sp-body" style={{ color: SP.body, fontSize: 12 }}>"{r.text}"</div>
            </div>
          ))}
        </div>
      </div>
    </SpPhone>
  );
};

// ─────────────────────────────────────────────────────────────
// 4. WRITE A REVIEW (Full screen variant)
// ─────────────────────────────────────────────────────────────
const SpReview = () => {
  const cats = [
    { label: 'GYM QUALITY',     value: 5 },
    { label: 'EXP LEVEL MATCH', value: 4 },
    { label: 'CLEANLINESS',     value: 5 },
    { label: 'FRIENDLINESS',    value: 0 },
  ];
  return (
    <SpPhone hasNav={false}>
      {/* MASTHEAD */}
      <div style={{
        padding: '4px 14px 10px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        background: SP.bg2, borderBottom: `1px solid ${SP.border}`,
      }}>
        <Icon name="close" size={18} color={SP.text} strokeWidth={2.5} />
        <span className="sp-mini" style={{ color: SP.muted }}>Post Review · Step 1 / 1</span>
        <div style={{ width: 18 }} />
      </div>

      {/* HERO */}
      <div style={{
        background: SP.bg2,
        padding: '14px 14px 14px',
        borderBottom: `1px solid ${SP.border}`,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
          <SpLive color={SP.green} label="Just Rolled" />
          <span style={{ width: 4, height: 4, background: SP.muted, marginTop: 1 }} />
          <span className="sp-mini" style={{ color: SP.muted }}>Mon Jun 2 · 7:00 PM</span>
        </div>
        <div className="sp-h1" style={{ color: SP.text, fontSize: 28 }}>Atos HQ</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 8 }}>
          <SpGiTag type="gi" />
          <SpExpTag level="all" />
        </div>
      </div>

      {/* INSTRUCTIONS */}
      <div style={{ padding: '14px 14px 8px' }}>
        <SpSectionHead accent={SP.red} title="Rate Categories" meta="REQUIRED" />
      </div>

      {/* CATEGORY ROWS — each is a horizontal interactive star strip */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 1, background: SP.border, margin: '0 14px' }}>
        {cats.map((c, i) => (
          <div key={i} style={{
            background: SP.surface, padding: '12px 14px',
            display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12,
          }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div className="sp-h2" style={{ color: SP.text, fontSize: 13 }}>{c.label}</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 1, marginTop: 6, height: 6 }}>
                {Array.from({ length: 5 }).map((_, j) => (
                  <div key={j} style={{
                    flex: 1, height: '100%',
                    background: j < c.value ? (c.value >= 4 ? SP.green : c.value >= 3 ? SP.amber : SP.red) : SP.surfaceLo,
                  }} />
                ))}
              </div>
            </div>
            <span className="sp-num" style={{
              color: c.value ? SP.text : SP.faint,
              fontSize: 28,
              minWidth: 28, textAlign: 'right',
            }}>{c.value || '—'}</span>
          </div>
        ))}
      </div>

      {/* SUMMARY SCORE */}
      <div style={{
        margin: '12px 14px 14px',
        background: SP.surfaceLo,
        borderLeft: `3px solid ${SP.amber}`,
        padding: '10px 12px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <span className="sp-mini" style={{ color: SP.muted }}>Composite Score</span>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
          <span className="sp-num" style={{ color: SP.amber, fontSize: 24 }}>3.5</span>
          <span className="sp-mini" style={{ color: SP.muted }}>/ 5.0 · INCOMPLETE</span>
        </div>
      </div>

      {/* NOTES */}
      <div style={{ padding: '0 14px 14px' }}>
        <SpSectionHead accent={SP.muted} title="Add Notes" sub="OPTIONAL" />
        <div style={{
          background: SP.surface, padding: 12, minHeight: 90, marginTop: 0,
          borderLeft: `2px solid ${SP.border}`,
        }}>
          <div className="sp-body" style={{ color: SP.text, fontWeight: 600 }}>
            Solid rolls tonight, good energy.
          </div>
          <div className="sp-body" style={{ color: SP.faint, marginTop: 6 }}>
            Tell other practitioners what to expect…
          </div>
        </div>
      </div>

      {/* CTA */}
      <div style={{ padding: '0 14px 14px' }}>
        <SpButton full icon="check">Post Review</SpButton>
      </div>
    </SpPhone>
  );
};

// ─────────────────────────────────────────────────────────────
// 5. GYM DETAIL — team profile / franchise card
// ─────────────────────────────────────────────────────────────
const SpGym = () => {
  const amenities = ['Parking', 'Showers', 'WiFi', 'Changing', 'Pro Shop', 'Water'];
  const upcoming = [
    { day: 'Tonight', date: 'Mon Jun 2', time: '7:00 PM', gi: 'gi'   },
    { day: 'Sat',     date: 'Jun 7',     time: '11:00 AM', gi: 'nogi' },
    { day: 'Sun',     date: 'Jun 8',     time: '12:00 PM', gi: 'both' },
  ];
  return (
    <SpPhone hasNav={false} hasStatusReserve={false}>
      {/* HERO — scoreboard banner */}
      <div style={{
        position: 'relative',
        background: `linear-gradient(135deg, ${SP.red} 0%, ${SP.both} 100%)`,
        padding: '54px 14px 14px',
      }}>
        {/* diagonal striping */}
        <svg width="100%" height="100%" style={{ position: 'absolute', inset: 0, opacity: 0.12, pointerEvents: 'none' }} viewBox="0 0 400 240" preserveAspectRatio="xMidYMid slice">
          <defs>
            <pattern id="sp-stripes" width="14" height="14" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
              <rect width="7" height="14" fill="white"/>
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#sp-stripes)"/>
        </svg>
        {/* nav row */}
        <div style={{ position: 'absolute', top: 60, left: 14, right: 14, display: 'flex', justifyContent: 'space-between' }}>
          <Icon name="arrow-l" size={20} color="#fff" strokeWidth={2.5} />
          <div style={{ display: 'flex', gap: 14 }}>
            <Icon name="heart-f" size={18} color="#fff" />
            <Icon name="more" size={20} color="#fff" />
          </div>
        </div>

        <div style={{ position: 'relative', paddingTop: 28 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
            <span className="sp-mini" style={{ color: 'rgba(255,255,255,0.85)' }}>Est. 2012 · Affiliate</span>
          </div>
          <div className="sp-h1" style={{ color: '#fff', fontSize: 36, letterSpacing: 0.02 }}>Atos HQ</div>
          <div className="sp-display" style={{ color: 'rgba(255,255,255,0.85)', fontSize: 16, marginTop: 2 }}>San Diego</div>
        </div>
      </div>

      {/* TEAM STAT STRIP */}
      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)',
        background: SP.bg2, borderBottom: `1px solid ${SP.border}`,
        padding: '14px 14px',
      }}>
        <SpCell label="RATING"   value="4.8" suffix="/5" color={SP.amber} accent={SP.amber} />
        <SpCell label="REVIEWS"  value="312" />
        <SpCell label="MATS/WK"  value="6" sub="DROP-IN" />
        <SpCell label="DIST"     value="1.2" suffix="MI" />
      </div>

      {/* ADDRESS / DIRECTIONS */}
      <div style={{
        display: 'grid', gridTemplateColumns: '1fr auto auto', gap: 1,
        background: SP.border,
      }}>
        <div style={{ background: SP.surface, padding: '12px 14px' }}>
          <div className="sp-mini" style={{ color: SP.muted }}>Venue</div>
          <div className="sp-h2" style={{ color: SP.text, fontSize: 13, marginTop: 3 }}>9587 Distribution Ave</div>
          <div className="sp-mini" style={{ color: SP.muted, marginTop: 2 }}>San Diego, CA 92121</div>
        </div>
        <button style={{
          background: SP.red, color: '#fff', border: 'none',
          padding: '0 14px', fontFamily: SP.display, fontWeight: 800, fontSize: 11,
          letterSpacing: 0.14, textTransform: 'uppercase', cursor: 'pointer',
          display: 'inline-flex', alignItems: 'center', gap: 5,
        }}>
          <Icon name="directions" size={14} color="#fff" strokeWidth={2.5} />
          Dir
        </button>
        <button style={{
          background: SP.surfaceHi, color: SP.text, border: 'none',
          padding: '0 14px', fontFamily: SP.display, fontWeight: 800, fontSize: 11,
          letterSpacing: 0.14, textTransform: 'uppercase', cursor: 'pointer',
          display: 'inline-flex', alignItems: 'center', gap: 5,
        }}>
          <Icon name="route" size={14} color={SP.gi} strokeWidth={2.5} />
          Waze
        </button>
      </div>

      {/* AMENITIES */}
      <div style={{ padding: '14px 14px 14px' }}>
        <SpSectionHead accent={SP.green} title="Facilities" />
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 1, background: SP.border, marginTop: 0 }}>
          {amenities.map((a, i) => (
            <div key={i} style={{
              background: SP.surface,
              padding: '8px 10px',
              display: 'flex', alignItems: 'center', gap: 6,
            }}>
              <Icon name="check" size={13} color={SP.green} strokeWidth={2.8} />
              <span className="sp-mini" style={{ color: SP.text, fontSize: 10 }}>{a}</span>
            </div>
          ))}
        </div>
      </div>

      {/* UPCOMING SCHEDULE — like a fixture list */}
      <div style={{ padding: '0 14px 14px' }}>
        <SpSectionHead accent={SP.red} title="Upcoming Open Mats" meta="THIS WEEK" sub="03 GAMES" />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 1, background: SP.border, marginTop: 0 }}>
          {upcoming.map((u, i) => {
            const c = { gi: SP.gi, nogi: SP.noGi, both: SP.both }[u.gi];
            return (
              <div key={i} style={{
                background: SP.surface,
                borderLeft: `3px solid ${c}`,
                display: 'grid', gridTemplateColumns: 'auto auto 1fr auto',
                gap: 10, alignItems: 'center', padding: '10px 12px',
              }}>
                <div style={{ minWidth: 50 }}>
                  <div className="sp-num" style={{ color: SP.text, fontSize: 13 }}>{u.day}</div>
                  <div className="sp-mini" style={{ color: SP.muted, marginTop: 1 }}>{u.date}</div>
                </div>
                <div style={{ width: 1, height: 22, background: SP.border }} />
                <div className="sp-num" style={{ color: SP.text, fontSize: 16 }}>{u.time}</div>
                <SpGiTag type={u.gi} size="sm" />
              </div>
            );
          })}
        </div>
      </div>

      {/* AGGREGATE RATINGS */}
      <div style={{ padding: '0 14px 22px' }}>
        <SpSectionHead accent={SP.amber} title="Aggregate Stats" sub="312 SAMPLES" />
        <div style={{ background: SP.surface, padding: '4px 14px', marginTop: 0 }}>
          <SpStatBar label="QUALITY"      value={4.9} color={SP.green} />
          <SpStatBar label="LEVEL MATCH"  value={4.6} color={SP.amber} />
          <SpStatBar label="CLEANLINESS"  value={4.9} color={SP.green} />
          <SpStatBar label="FRIENDLINESS" value={4.8} color={SP.green} />
        </div>
      </div>
    </SpPhone>
  );
};

// ─────────────────────────────────────────────────────────────
// 6. REGISTRATION WIZARD (Step 1)
// ─────────────────────────────────────────────────────────────
const SpRegister = () => {
  return (
    <SpPhone hasNav={false}>
      {/* MASTHEAD */}
      <div style={{
        padding: '4px 14px 10px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        background: SP.bg2, borderBottom: `1px solid ${SP.border}`,
      }}>
        <Icon name="close" size={18} color={SP.text} strokeWidth={2.5} />
        <span className="sp-mini" style={{ color: SP.muted }}>Register Gym · 01 / 03</span>
        <div style={{ width: 18 }} />
      </div>

      {/* SEGMENTED PROGRESS */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 4, padding: '12px 14px 14px', background: SP.bg2 }}>
        {[
          { n: '01', label: 'BASICS', active: true,  done: false },
          { n: '02', label: 'CONTACT', active: false, done: false },
          { n: '03', label: 'FACILITY', active: false, done: false },
        ].map((s, i) => (
          <div key={i} style={{
            padding: '8px 9px 9px',
            background: s.active ? SP.surfaceHi : SP.surface,
            borderTop: `3px solid ${s.active ? SP.red : (s.done ? SP.green : SP.border)}`,
          }}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
              <span className="sp-num" style={{ color: s.active ? SP.text : SP.faint, fontSize: 16 }}>{s.n}</span>
              <span className="sp-mini" style={{ color: s.active ? SP.amber : SP.muted, fontSize: 9 }}>{s.label}</span>
            </div>
          </div>
        ))}
      </div>

      {/* TITLE */}
      <div style={{ padding: '4px 14px 14px' }}>
        <div className="sp-mini" style={{ color: SP.red }}>STEP 01 · BASIC INFO</div>
        <div className="sp-h1" style={{ color: SP.text, fontSize: 26, marginTop: 4 }}>Register Your Gym</div>
        <div className="sp-body" style={{ color: SP.muted, marginTop: 4 }}>Help practitioners find you.</div>
      </div>

      {/* GYM NAME */}
      <div style={{ padding: '0 14px 12px' }}>
        <div className="sp-mini" style={{ color: SP.muted, marginBottom: 6 }}>Gym Name</div>
        <div style={{
          background: SP.surface, padding: '12px 14px',
          borderLeft: `3px solid ${SP.border}`,
        }}>
          <span className="sp-h2" style={{ color: SP.text, fontSize: 15 }}>Atos Jiu-Jitsu HQ</span>
        </div>
      </div>

      {/* ADDRESS WITH AUTOCOMPLETE */}
      <div style={{ padding: '0 14px 12px' }}>
        <div className="sp-mini" style={{ color: SP.muted, marginBottom: 6 }}>Address Autocomplete</div>
        <div style={{
          background: SP.surface,
          borderLeft: `3px solid ${SP.red}`,
        }}>
          <div style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 10, borderBottom: `1px solid ${SP.border}` }}>
            <Icon name="search" size={15} color={SP.red} strokeWidth={2.5} />
            <span className="sp-h2" style={{ color: SP.text, fontSize: 14 }}>9587 Distribution</span>
            <div style={{ flex: 1 }} />
            <span className="sp-mini" style={{ color: SP.muted }}>3 hits</span>
          </div>
          {[
            { main: '9587 Distribution Ave', sub: 'San Diego, CA 92121', highlight: true },
            { main: '9587 Distribution Way', sub: 'Vista, CA 92081' },
            { main: '9587 Distribution Blvd', sub: 'Los Angeles, CA 90015' },
          ].map((s, i) => (
            <div key={i} style={{
              padding: '10px 14px',
              borderBottom: i < 2 ? `1px solid ${SP.border}` : 'none',
              display: 'flex', alignItems: 'center', gap: 10,
              background: s.highlight ? SP.surfaceHi : 'transparent',
              borderLeft: s.highlight ? `2px solid ${SP.amber}` : '2px solid transparent',
            }}>
              <Icon name="pin" size={13} color={s.highlight ? SP.amber : SP.muted} />
              <div style={{ flex: 1 }}>
                <div className="sp-h2" style={{ color: SP.text, fontSize: 12 }}>{s.main}</div>
                <div className="sp-mini" style={{ color: SP.muted, marginTop: 1 }}>{s.sub}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* VERIFIED CHIP */}
      <div style={{ padding: '0 14px 14px' }}>
        <div style={{
          background: SP.green + '12',
          borderLeft: `3px solid ${SP.green}`,
          padding: '12px 14px',
          display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <Icon name="check" size={18} color={SP.green} strokeWidth={3} />
          <div style={{ flex: 1 }}>
            <div className="sp-mini" style={{ color: SP.green, fontSize: 9 }}>Location Verified</div>
            <div className="sp-h2" style={{ color: SP.text, fontSize: 12, marginTop: 2 }}>32.9010 N · -117.2130 W</div>
          </div>
        </div>
      </div>

      {/* FOOTER */}
      <div style={{ marginTop: 'auto', padding: '14px', display: 'flex', gap: 8, background: SP.bg2, borderTop: `1px solid ${SP.border}` }}>
        <button style={{
          flex: '0 0 auto', padding: '0 18px', height: 54,
          background: SP.surface, color: SP.muted, border: `1px solid ${SP.border}`,
          fontFamily: SP.display, fontWeight: 800, fontSize: 14,
          letterSpacing: 0.14, textTransform: 'uppercase', cursor: 'pointer',
        }}>Back</button>
        <div style={{ flex: 1 }}>
          <SpButton full icon="arrow-r">Continue</SpButton>
        </div>
      </div>
    </SpPhone>
  );
};

// ─────────────────────────────────────────────────────────────
// 7. CREATE OPEN MAT SESSION — coach's worksheet
// ─────────────────────────────────────────────────────────────
const SpCreate = () => {
  const giOptions = [
    { id: 'gi',   label: 'Gi',       icon: 'gi',     color: SP.gi   },
    { id: 'nogi', label: 'No-Gi',    icon: 'shirt',  color: SP.noGi },
    { id: 'both', label: 'Gi+No-Gi', icon: 'swords', color: SP.both, active: true },
  ];
  const expOpts = [
    { label: 'ALL LV',  color: SP.allLevels,    on: true },
    { label: 'BEGIN',   color: SP.beginner,     on: false },
    { label: 'INTER',   color: SP.intermediate, on: false },
    { label: 'ADV',     color: SP.advanced,     on: false },
  ];
  return (
    <SpPhone hasNav={false}>
      {/* MASTHEAD */}
      <div style={{
        padding: '4px 14px 10px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        background: SP.bg2, borderBottom: `1px solid ${SP.border}`,
      }}>
        <Icon name="close" size={18} color={SP.text} strokeWidth={2.5} />
        <span className="sp-mini" style={{ color: SP.muted }}>New Session</span>
        <div style={{ width: 18 }} />
      </div>

      {/* TITLE STRIP */}
      <div style={{ padding: '14px 14px 12px' }}>
        <div className="sp-mini" style={{ color: SP.red }}>POSTING AS</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
          <div style={{ width: 32, height: 32, background: SP.red, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: SP.display, fontWeight: 800, fontSize: 14 }}>A</div>
          <div>
            <div className="sp-h2" style={{ color: SP.text, fontSize: 14 }}>Atos HQ — San Diego</div>
            <div className="sp-mini" style={{ color: SP.muted, marginTop: 2 }}>3 gyms managed · tap to switch</div>
          </div>
        </div>
      </div>

      {/* ALERT */}
      <div style={{ padding: '0 14px 14px' }}>
        <div style={{
          background: SP.amber + '15',
          borderLeft: `3px solid ${SP.amber}`,
          padding: '9px 12px',
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <Icon name="bell" size={14} color={SP.amber} />
          <div style={{ flex: 1 }} className="sp-mini">
            <span style={{ color: SP.amber, fontSize: 10 }}>WARNING · </span>
            <span style={{ color: SP.body, fontSize: 10 }}>1 of 2 sessions already posted for Sat Jun 7</span>
          </div>
        </div>
      </div>

      {/* DATE / TIME STRIP — scoreboard cells */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 1, background: SP.border, margin: '0 14px 14px' }}>
        <div style={{ background: SP.surface, padding: '11px 12px' }}>
          <div className="sp-mini" style={{ color: SP.muted, fontSize: 9 }}>Date</div>
          <div className="sp-num" style={{ color: SP.text, fontSize: 16, marginTop: 3 }}>JUN 07</div>
          <div className="sp-mini" style={{ color: SP.faint, marginTop: 2 }}>SAT</div>
        </div>
        <div style={{ background: SP.surface, padding: '11px 12px' }}>
          <div className="sp-mini" style={{ color: SP.muted, fontSize: 9 }}>Start</div>
          <div className="sp-num" style={{ color: SP.text, fontSize: 16, marginTop: 3 }}>10:00</div>
          <div className="sp-mini" style={{ color: SP.faint, marginTop: 2 }}>AM PT</div>
        </div>
        <div style={{ background: SP.surface, padding: '11px 12px' }}>
          <div className="sp-mini" style={{ color: SP.muted, fontSize: 9 }}>End</div>
          <div className="sp-num" style={{ color: SP.text, fontSize: 16, marginTop: 3 }}>12:00</div>
          <div className="sp-mini" style={{ color: SP.faint, marginTop: 2 }}>PM PT</div>
        </div>
      </div>

      {/* GI TYPE SELECTOR */}
      <div style={{ padding: '0 14px 14px' }}>
        <SpSectionHead accent={SP.both} title="Gi Format" />
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 1, background: SP.border, marginTop: 0 }}>
          {giOptions.map(o => (
            <div key={o.id} style={{
              background: o.active ? o.color + '20' : SP.surface,
              borderTop: `3px solid ${o.active ? o.color : 'transparent'}`,
              padding: '13px 8px 10px',
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
            }}>
              <Icon name={o.icon} size={22} color={o.active ? o.color : SP.muted} strokeWidth={2.5} />
              <span style={{
                fontFamily: SP.display, fontWeight: 800, fontSize: 11,
                letterSpacing: 0.14, textTransform: 'uppercase',
                color: o.active ? o.color : SP.body,
              }}>{o.label}</span>
            </div>
          ))}
        </div>
      </div>

      {/* EXPERIENCE LEVEL */}
      <div style={{ padding: '0 14px 14px' }}>
        <SpSectionHead accent={SP.green} title="Experience Level" />
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 1, background: SP.border, marginTop: 0 }}>
          {expOpts.map((e, i) => (
            <div key={i} style={{
              background: e.on ? e.color + '20' : SP.surface,
              borderTop: `3px solid ${e.on ? e.color : 'transparent'}`,
              padding: '10px 6px',
              textAlign: 'center',
              color: e.on ? e.color : SP.muted,
              fontFamily: SP.display, fontWeight: 800, fontSize: 11, letterSpacing: 0.16,
            }}>{e.label}</div>
          ))}
        </div>
      </div>

      {/* FEE */}
      <div style={{ padding: '0 14px 14px' }}>
        <div style={{
          background: SP.surface,
          borderLeft: `3px solid ${SP.green}`,
          padding: '12px 14px',
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <div style={{ flex: 1 }}>
            <div className="sp-mini" style={{ color: SP.muted }}>Mat Fee</div>
            <div className="sp-num" style={{ color: SP.green, fontSize: 22, marginTop: 3 }}>FREE</div>
          </div>
          <div style={{ width: 50, height: 26, background: SP.green, position: 'relative' }}>
            <div style={{ position: 'absolute', right: 2, top: 2, bottom: 2, width: 22, background: '#fff' }} />
          </div>
        </div>
      </div>

      {/* NOTES */}
      <div style={{ padding: '0 14px 14px' }}>
        <SpSectionHead accent={SP.muted} title="Notes" sub="OPTIONAL" />
        <div style={{ background: SP.surface, padding: 12, minHeight: 60, marginTop: 0 }}>
          <div className="sp-body" style={{ color: SP.text }}>Visitors welcome. Bring both gi and rashguard.</div>
        </div>
      </div>

      {/* SUBMIT */}
      <div style={{ padding: '0 14px 18px' }}>
        <SpButton full icon="plus">Post Open Mat</SpButton>
      </div>
    </SpPhone>
  );
};

// ─────────────────────────────────────────────────────────────
// 8. PROFILE — player card
// ─────────────────────────────────────────────────────────────
const SpProfile = () => {
  const recent = SESSIONS.slice(0, 2);
  return (
    <SpPhone>
      {/* MASTHEAD */}
      <div style={{
        padding: '4px 14px 10px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        background: SP.bg2, borderBottom: `1px solid ${SP.border}`,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 4, height: 22, background: SP.red }} />
          <div className="sp-display" style={{ fontSize: 18, color: SP.text }}>Player Card</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <Icon name="bell" size={18} color={SP.muted} />
          <Icon name="settings" size={18} color={SP.muted} />
        </div>
      </div>

      {/* PLAYER HERO */}
      <div style={{
        background: SP.bg2,
        padding: '16px 14px 14px',
        borderBottom: `1px solid ${SP.border}`,
        display: 'flex', alignItems: 'center', gap: 14,
      }}>
        <div style={{
          width: 78, height: 78,
          background: `linear-gradient(135deg, ${SP.red}, ${SP.both})`,
          color: '#fff',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontFamily: SP.display, fontWeight: 800, fontSize: 32,
          border: `2px solid ${SP.borderHi}`,
        }}>MR</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div className="sp-mini" style={{ color: SP.muted }}>#0027 · MEMBER SINCE 2023</div>
          <div className="sp-h1" style={{ color: SP.text, fontSize: 26, marginTop: 3 }}>Mateo Reyes</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 8 }}>
            <SpBelt belt="purple" stripes={2} />
            <span className="sp-mini" style={{ color: SP.muted, marginLeft: 2 }}>San Diego · CA</span>
          </div>
        </div>
      </div>

      {/* STATS GRID */}
      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 1,
        background: SP.border, borderBottom: `1px solid ${SP.border}`,
      }}>
        <div style={{ background: SP.surfaceLo, padding: '14px 8px', textAlign: 'center' }}>
          <SpCell label="MATS"     value="27" />
        </div>
        <div style={{ background: SP.surfaceLo, padding: '14px 8px', textAlign: 'center' }}>
          <SpCell label="HOURS"    value="48" accent={SP.amber} />
        </div>
        <div style={{ background: SP.surfaceLo, padding: '14px 8px', textAlign: 'center' }}>
          <SpCell label="GYMS"     value="9" />
        </div>
        <div style={{ background: SP.surfaceLo, padding: '14px 8px', textAlign: 'center' }}>
          <SpCell label="REVIEWS"  value="8" accent={SP.green} />
        </div>
      </div>

      {/* BELT PROGRESSION BAR */}
      <div style={{ padding: '14px 14px 14px', background: SP.bg2, borderBottom: `1px solid ${SP.border}` }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
          <span className="sp-mini" style={{ color: SP.muted }}>Belt Progression</span>
          <span className="sp-mini" style={{ color: SP.amber }}>2 stripes · purple</span>
        </div>
        <div style={{ display: 'flex', gap: 2, height: 14 }}>
          {[
            { c: '#E5E5E5', done: true },
            { c: '#1E5BC9', done: true },
            { c: '#7A2BB5', done: true, current: true },
            { c: '#6B3A1A', done: false },
            { c: '#0A0A0A', done: false },
          ].map((b, i) => (
            <div key={i} style={{
              flex: 1, background: b.done ? b.c : SP.surface,
              borderTop: b.current ? `2px solid ${SP.amber}` : 'none',
              opacity: b.done ? 1 : 0.5,
            }} />
          ))}
        </div>
      </div>

      {/* RECENT MATS */}
      <div style={{ padding: '14px 14px 14px' }}>
        <SpSectionHead accent={SP.red} title="Recent Mats" meta="LAST 30D" sub="08 LOGGED" />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 1, background: SP.border, marginTop: 0 }}>
          {recent.map(s => <SpSessionRow key={s.id} session={s} />)}
        </div>
      </div>

      {/* FAVORITE GYMS */}
      <div style={{ padding: '0 14px 14px' }}>
        <SpSectionHead accent={SP.amber} title="Favorite Gyms" sub="03" />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 1, background: SP.border, marginTop: 0 }}>
          {[
            { name: 'Atos HQ',            city: 'San Diego',    rating: '4.8', dist: '1.2' },
            { name: 'Gracie Barra DTLA',  city: 'Los Angeles',  rating: '4.5', dist: '2.4' },
            { name: '10P Rosemead',       city: 'Rosemead',     rating: '4.7', dist: '4.1' },
          ].map((f, i) => (
            <div key={i} style={{
              background: SP.surface,
              padding: '10px 12px',
              display: 'grid', gridTemplateColumns: '1fr auto auto', gap: 10, alignItems: 'center',
            }}>
              <div>
                <div className="sp-h2" style={{ color: SP.text, fontSize: 13 }}>{f.name}</div>
                <div className="sp-mini" style={{ color: SP.muted, marginTop: 2 }}>{f.city}</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div className="sp-mini" style={{ color: SP.muted, fontSize: 9 }}>RTG</div>
                <div className="sp-num" style={{ color: SP.amber, fontSize: 14, marginTop: 2 }}>{f.rating}</div>
              </div>
              <div style={{ textAlign: 'right', minWidth: 36 }}>
                <div className="sp-mini" style={{ color: SP.muted, fontSize: 9 }}>DIST</div>
                <div className="sp-num" style={{ color: SP.text, fontSize: 14, marginTop: 2 }}>{f.dist}<span className="sp-mini" style={{ color: SP.faint, marginLeft: 2 }}>MI</span></div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <SpBottomNav active="profile" />
    </SpPhone>
  );
};

Object.assign(window, {
  SpHome, SpSearch, SpDetail, SpReview, SpGym, SpRegister, SpCreate, SpProfile,
});
