// screens.jsx — All 8 screens for Open Mat BJJ app — LIGHT GLASS theme.
// Glass surfaces (translucent white + backdrop-blur) over a colorful pastel
// gradient backdrop so the blur actually reads. All screens fit IOSDevice
// 402×874.

// Shared glass-pill style (small floating chip)
const glassPill = (style = {}) => ({
  background: 'rgba(255,255,255,0.65)',
  backdropFilter: 'blur(20px) saturate(180%)',
  WebkitBackdropFilter: 'blur(20px) saturate(180%)',
  border: `1px solid ${OM.borderDark}`,
  boxShadow: 'inset 1.5px 1.5px 1px rgba(255,255,255,0.95), inset -1px -1px 1px rgba(255,255,255,0.5), 0 8px 24px rgba(20,20,40,0.08)',
  ...style,
});

// Phone wrapper: colorful gradient under glass
const Phone = ({ children, scroll = true, hasNav = true, hasStatusReserve = true }) => (
  <div style={{
    background: OM.bgGradient,
    width: '100%', height: '100%',
    color: OM.text, fontFamily: OM.body_f,
    display: 'flex', flexDirection: 'column',
    paddingTop: hasStatusReserve ? 54 : 0,
    paddingBottom: hasNav ? 96 : 0,
    overflow: scroll ? 'auto' : 'hidden',
    position: 'relative',
  }} className="om-scroll">
    {children}
  </div>
);

// ─────────────────────────────────────────────────────────────
// 1. HOME / DISCOVERY
// ─────────────────────────────────────────────────────────────
const ScreenHome = () => {
  const pins = [
    { x: 22, y: 35, gi: 'gi'   },
    { x: 55, y: 30, gi: 'both', active: true },
    { x: 78, y: 50, gi: 'nogi' },
    { x: 35, y: 65, gi: 'gi'   },
    { x: 68, y: 78, gi: 'nogi' },
    { x: 15, y: 80, gi: 'both' },
  ];
  return (
    <div style={{ background: OM.bgGradient, width: '100%', height: '100%', position: 'relative', color: OM.text, fontFamily: OM.body_f, overflow: 'hidden' }}>
      {/* Map (top half) */}
      <div style={{ position: 'relative', height: 420 }}>
        <MapBackdrop height={420} pins={pins} />
        {/* status bar light overlay */}
        <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 60,
          background: 'linear-gradient(to bottom, rgba(255,255,255,0.6), transparent)' }} />
        {/* floating search bar — glass */}
        <div style={{ position: 'absolute', top: 60, left: 16, right: 16, display: 'flex', gap: 10, alignItems: 'center' }}>
          <div style={glassPill({
            flex: 1, height: 52, borderRadius: 18,
            display: 'flex', alignItems: 'center', padding: '0 14px', gap: 10,
          })}>
            <Icon name="search" size={18} color={OM.muted} />
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, color: OM.text, fontWeight: 600 }}>Search gyms or area</div>
              <div style={{ fontSize: 11, color: OM.muted, marginTop: 1 }}>Los Angeles, CA · 10mi</div>
            </div>
            <div style={{ width: 1, height: 22, background: OM.borderDark }} />
            <Icon name="sliders" size={18} color={OM.crimson} strokeWidth={2.5} />
          </div>
        </div>
        {/* GPS pill */}
        <div style={glassPill({
          position: 'absolute', right: 16, bottom: 16, width: 46, height: 46, borderRadius: 16,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        })}>
          <Icon name="gps" size={20} color={OM.crimson} strokeWidth={2.5} />
        </div>
        {/* count chip */}
        <div style={glassPill({
          position: 'absolute', left: 16, bottom: 16, padding: '9px 14px', borderRadius: 999,
          display: 'flex', alignItems: 'center', gap: 7,
        })}>
          <span style={{ width: 8, height: 8, borderRadius: 99, background: OM.teal, boxShadow: `0 0 8px ${OM.teal}` }} />
          <span style={{ fontFamily: OM.display, fontWeight: 700, fontSize: 12, color: OM.text, textTransform: 'uppercase', letterSpacing: 0.1 }}>
            18 mats open near you
          </span>
        </div>
      </div>

      {/* Bottom sheet — glass over gradient */}
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0, top: 380,
        background: 'rgba(255,255,255,0.55)',
        backdropFilter: 'blur(28px) saturate(180%)',
        WebkitBackdropFilter: 'blur(28px) saturate(180%)',
        borderTopLeftRadius: 28, borderTopRightRadius: 28,
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.95), 0 -20px 60px rgba(20,20,40,0.06)',
        border: `1px solid ${OM.borderDark}`,
        borderBottom: 'none',
        display: 'flex', flexDirection: 'column',
        paddingBottom: 96,
      }}>
        {/* drag handle */}
        <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 10, paddingBottom: 6 }}>
          <div style={{ width: 44, height: 5, background: 'rgba(20,20,40,0.18)', borderRadius: 99 }} />
        </div>
        {/* section header */}
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', padding: '6px 18px 14px' }}>
          <div>
            <div className="om-eyebrow" style={{ color: OM.crimson }}>Tonight & Tomorrow</div>
            <div className="om-h1" style={{ fontSize: 28, color: OM.text, marginTop: 4 }}>Open Mats</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, color: OM.muted }}>
            <span className="om-eyebrow">See all</span>
            <Icon name="arrow-r" size={14} color={OM.muted} strokeWidth={2.5} />
          </div>
        </div>
        {/* horizontal cards */}
        <div className="om-scroll" style={{ display: 'flex', gap: 12, padding: '0 18px 18px', overflowX: 'auto', scrollSnapType: 'x mandatory' }}>
          {SESSIONS.slice(0, 4).map(s => (
            <div key={s.id} style={{ scrollSnapAlign: 'start', flex: '0 0 auto' }}>
              <SessionCard session={s} width={266} />
            </div>
          ))}
        </div>
      </div>

      <BottomNav active="home" />
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// 2. SEARCH & FILTER
// ─────────────────────────────────────────────────────────────
const ScreenSearch = () => {
  const filters = [
    { label: 'Gi', active: true, color: OM.gi },
    { label: 'No-Gi', active: false, color: OM.noGi },
    { label: 'Both', active: true, color: OM.both },
    { label: 'Free', active: true, color: OM.teal },
    { label: 'All Levels', active: false },
    { label: 'Beginner', active: false },
  ];
  return (
    <Phone>
      {/* header */}
      <div style={{ padding: '8px 18px 14px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <div className="om-h1" style={{ color: OM.text }}>Find a Mat</div>
          <div style={glassPill({ width: 38, height: 38, borderRadius: 13, display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
            <Icon name="pin" size={18} color={OM.crimson} />
          </div>
        </div>
        {/* location input */}
        <div className="om-card" style={{
          display: 'flex', alignItems: 'center', gap: 10, padding: '0 14px',
          height: 56, borderRadius: 18,
        }}>
          <Icon name="search" size={18} color={OM.muted} />
          <div style={{ flex: 1, color: OM.text, fontSize: 15, fontWeight: 600 }}>Los Angeles, CA</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '6px 10px', borderRadius: 10, background: OM.crimson + '22', color: OM.crimson }}>
            <Icon name="gps" size={14} color={OM.crimson} strokeWidth={2.5} />
            <span style={{ fontFamily: OM.display, fontWeight: 700, fontSize: 11, letterSpacing: 0.1, textTransform: 'uppercase' }}>GPS</span>
          </div>
        </div>
      </div>

      {/* filter chips */}
      <div className="om-scroll" style={{ display: 'flex', gap: 8, padding: '0 18px 16px', overflowX: 'auto' }}>
        {filters.map((f, i) => (
          <span key={i} style={{
            flex: '0 0 auto',
            padding: '8px 14px', borderRadius: 999,
            background: f.active ? (f.color ? f.color + '2A' : OM.crimson + '22') : 'rgba(255,255,255,0.55)',
            backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)',
            border: `1px solid ${f.active ? (f.color || OM.crimson) + '88' : OM.borderDark}`,
            color: f.active ? (f.color || OM.crimson) : OM.body,
            fontFamily: OM.display, fontWeight: 700, fontSize: 12, letterSpacing: 0.1, textTransform: 'uppercase',
            display: 'inline-flex', alignItems: 'center', gap: 6,
            boxShadow: 'inset 1px 1px 0 rgba(255,255,255,0.7)',
          }}>
            {f.active && <Icon name="check" size={12} color={f.color || OM.crimson} strokeWidth={3} />}
            {f.label}
          </span>
        ))}
      </div>

      {/* date + distance row */}
      <div style={{ display: 'flex', gap: 10, padding: '0 18px 16px' }}>
        <div className="om-card" style={{ flex: 1, padding: '12px 14px' }}>
          <div className="om-eyebrow" style={{ color: OM.muted, fontSize: 10 }}>When</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4 }}>
            <Icon name="calendar" size={14} color={OM.crimson} />
            <span style={{ fontSize: 13, color: OM.text, fontWeight: 600 }}>This Weekend</span>
          </div>
        </div>
        <div className="om-card" style={{ flex: 1, padding: '12px 14px' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div className="om-eyebrow" style={{ color: OM.muted, fontSize: 10 }}>Within</div>
            <span className="om-num" style={{ color: OM.text, fontSize: 13 }}>8 mi</span>
          </div>
          <div style={{ marginTop: 8, height: 4, background: 'rgba(20,20,40,0.08)', borderRadius: 99, position: 'relative' }}>
            <div style={{ height: '100%', width: '40%', background: OM.crimson, borderRadius: 99 }} />
            <div style={{ position: 'absolute', left: '40%', top: '50%', transform: 'translate(-50%,-50%)', width: 14, height: 14, borderRadius: 99, background: '#fff', boxShadow: '0 2px 6px rgba(20,20,40,0.25), 0 0 0 1px rgba(20,20,40,0.05)' }} />
          </div>
        </div>
      </div>

      {/* results header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 18px 10px' }}>
        <div className="om-h2" style={{ color: OM.text, fontSize: 16 }}>
          <span style={{ color: OM.crimson }}>12</span> Sessions
        </div>
        <div style={glassPill({
          display: 'flex', alignItems: 'center', gap: 6, padding: '7px 11px', borderRadius: 11,
        })}>
          <Icon name="pin" size={13} color={OM.crimson} strokeWidth={2.5} />
          <span style={{ fontFamily: OM.display, fontWeight: 700, fontSize: 11, color: OM.text, letterSpacing: 0.1, textTransform: 'uppercase' }}>Map View</span>
        </div>
      </div>

      {/* results */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '0 18px' }}>
        {SESSIONS.slice(0, 4).map(s => <SessionCard key={s.id} session={s} />)}
      </div>
      <BottomNav active="search" />
    </Phone>
  );
};

// ─────────────────────────────────────────────────────────────
// 3. OPEN MAT DETAIL
// ─────────────────────────────────────────────────────────────
const ScreenDetail = () => {
  const reviews = [
    { name: 'Marcus T.', belt: 'purple', stripes: 2, rating: 5, when: '2 days ago', text: 'Awesome rolls, mat space was spotless. Beginners felt welcome.' },
    { name: 'Jenna K.',  belt: 'blue', stripes: 4, rating: 4, when: '1 wk ago', text: 'Good mix of belts. Wish it ran a bit longer.' },
  ];
  return (
    <Phone hasNav={false}>
      {/* hero */}
      <div style={{ position: 'relative', padding: '0 18px 18px' }}>
        {/* back / heart */}
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 18 }}>
          <div style={glassPill({ width: 40, height: 40, borderRadius: 13, display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
            <Icon name="arrow-l" size={18} color={OM.text} strokeWidth={2.5} />
          </div>
          <div style={glassPill({ width: 40, height: 40, borderRadius: 13, display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
            <Icon name="heart" size={18} color={OM.text} strokeWidth={2} />
          </div>
        </div>
        {/* hero card — glass tinted purple */}
        <div style={{
          background: `linear-gradient(135deg, ${OM.both}33 0%, rgba(255,255,255,0.65) 70%)`,
          backdropFilter: 'blur(24px) saturate(180%)', WebkitBackdropFilter: 'blur(24px) saturate(180%)',
          border: `1px solid ${OM.borderDark}`,
          borderRadius: 22, padding: '18px 18px 20px',
          position: 'relative', overflow: 'hidden',
          boxShadow: 'inset 1.5px 1.5px 1px rgba(255,255,255,0.95), 0 12px 32px rgba(156,39,176,0.18)',
        }}>
          <div style={{ position: 'absolute', top: -30, right: -30, width: 140, height: 140, borderRadius: 99, background: `radial-gradient(circle, ${OM.both}55, transparent 70%)`, filter: 'blur(20px)' }} />
          <div style={{ position: 'relative' }}>
            <div className="om-eyebrow" style={{ color: OM.both }}>Open Mat</div>
            <div className="om-h1" style={{ color: OM.text, fontSize: 28, marginTop: 4 }}>10th Planet Rosemead</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 14 }}>
              <Icon name="calendar" size={16} color={OM.muted} />
              <span style={{ fontSize: 14, color: OM.body, fontWeight: 600 }}>Sun, Jun 8 · 12:00 – 2:00 PM</span>
            </div>
            <div style={{ display: 'flex', gap: 8, marginTop: 16, flexWrap: 'wrap' }}>
              <GiBadge type="both" />
              <ExpBadge level="all" />
              <span style={{
                display: 'inline-flex', alignItems: 'center', gap: 5,
                padding: '4px 10px', borderRadius: 999,
                background: OM.teal + '22', color: OM.teal,
                border: `1px solid ${OM.teal}44`,
                fontFamily: OM.display, fontWeight: 700, fontSize: 11, letterSpacing: 0.08, textTransform: 'uppercase',
              }}>
                <Icon name="dollar" size={11} color={OM.teal} strokeWidth={3} />
                $10 Mat Fee
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* address row */}
      <div style={{ padding: '0 18px 16px' }}>
        <div className="om-card" style={{ padding: 14, display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 40, height: 40, borderRadius: 12, background: OM.crimson + '22', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="pin" size={18} color={OM.crimson} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, color: OM.text, fontWeight: 600 }}>3851 Rosemead Blvd</div>
            <div style={{ fontSize: 12, color: OM.muted }}>Rosemead, CA · 4.1 mi away</div>
          </div>
          <div style={{ padding: '8px 12px', borderRadius: 10, background: OM.crimson, color: '#fff',
            fontFamily: OM.display, fontWeight: 700, fontSize: 11, letterSpacing: 0.1, textTransform: 'uppercase',
            display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="directions" size={13} color="#fff" strokeWidth={2.5} />
            Go
          </div>
        </div>
      </div>

      {/* CTA */}
      <div style={{ padding: '0 18px 22px' }}>
        <PrimaryBtn full icon="check">Check In to This Open Mat</PrimaryBtn>
      </div>

      {/* Ratings */}
      <div style={{ padding: '0 18px 18px' }}>
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginBottom: 10 }}>
          <div className="om-h2" style={{ color: OM.text, fontSize: 18 }}>Mat Ratings</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <Icon name="star" size={16} color="#FFC857" />
            <span className="om-num" style={{ color: OM.text, fontSize: 16 }}>4.7</span>
            <span style={{ color: OM.muted, fontSize: 12 }}>· 84 reviews</span>
          </div>
        </div>
        <div className="om-card" style={{ padding: '6px 16px' }}>
          <StarRow label="Gym Quality" value={4.8} count={84} dark={false} />
          <div style={{ height: 1, background: OM.borderDark }} />
          <StarRow label="Experience Level Match" value={4.5} count={84} dark={false} />
          <div style={{ height: 1, background: OM.borderDark }} />
          <StarRow label="Cleanliness" value={4.9} count={84} dark={false} />
          <div style={{ height: 1, background: OM.borderDark }} />
          <StarRow label="Friendliness" value={4.7} count={84} dark={false} />
        </div>
      </div>

      {/* Reviews */}
      <div style={{ padding: '0 18px 24px' }}>
        <div className="om-h2" style={{ color: OM.text, fontSize: 18, marginBottom: 10 }}>Recent Reviews</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {reviews.map((r, i) => (
            <div key={i} className="om-card" style={{ padding: 14 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
                <div style={{ width: 36, height: 36, borderRadius: 99, background: `linear-gradient(135deg, ${OM.crimson}, ${OM.both})`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontFamily: OM.display, fontWeight: 700, fontSize: 14 }}>
                  {r.name[0]}
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 13, color: OM.text, fontWeight: 600 }}>{r.name}</div>
                  <div style={{ marginTop: 3, display: 'flex', alignItems: 'center', gap: 6 }}>
                    <BeltBadge belt={r.belt} stripes={r.stripes} size="sm" />
                  </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ display: 'flex', gap: 1, justifyContent: 'flex-end' }}>
                    {Array.from({ length: 5 }).map((_, j) => (
                      <Icon key={j} name="star" size={11} color={j < r.rating ? '#FFC857' : 'rgba(20,20,40,0.18)'} />
                    ))}
                  </div>
                  <div style={{ fontSize: 11, color: OM.muted, marginTop: 2 }}>{r.when}</div>
                </div>
              </div>
              <div style={{ fontSize: 13, color: OM.body, lineHeight: 1.45 }}>"{r.text}"</div>
            </div>
          ))}
        </div>
      </div>
    </Phone>
  );
};

// ─────────────────────────────────────────────────────────────
// 4. WRITE A REVIEW (Bottom Sheet)
// ─────────────────────────────────────────────────────────────
const ScreenReview = () => {
  return (
    <div style={{ background: OM.bgGradient, width: '100%', height: '100%', position: 'relative', color: OM.text, fontFamily: OM.body_f, overflow: 'hidden' }}>
      {/* dimmed parent screen behind */}
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,20,40,0.18)', backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)' }} />

      {/* sheet — frosted */}
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        background: 'rgba(255,255,255,0.78)',
        backdropFilter: 'blur(32px) saturate(180%)',
        WebkitBackdropFilter: 'blur(32px) saturate(180%)',
        borderTopLeftRadius: 28, borderTopRightRadius: 28,
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.95), 0 -24px 60px rgba(20,20,40,0.12)',
        paddingBottom: 36,
        border: `1px solid ${OM.borderDark}`,
        borderBottom: 'none',
      }}>
        {/* handle */}
        <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 10, paddingBottom: 6 }}>
          <div style={{ width: 44, height: 5, background: 'rgba(20,20,40,0.22)', borderRadius: 99 }} />
        </div>
        {/* header */}
        <div style={{ padding: '12px 22px 16px' }}>
          <div className="om-eyebrow" style={{ color: OM.crimson }}>You just rolled at</div>
          <div className="om-h1" style={{ color: OM.text, fontSize: 26, marginTop: 4 }}>Atos HQ</div>
          <div style={{ color: OM.muted, fontSize: 13, marginTop: 2 }}>Tonight · 7:00 – 9:00 PM</div>
        </div>
        {/* category stars */}
        <div style={{ padding: '0 22px 16px' }}>
          {[
            { label: 'Gym Quality', value: 5 },
            { label: 'Experience Level Match', value: 4 },
            { label: 'Cleanliness', value: 5 },
            { label: 'Friendliness', value: 0 },
          ].map((r, i) => (
            <div key={i} className="om-card" style={{
              padding: '14px 14px', marginBottom: 8,
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            }}>
              <div style={{ fontFamily: OM.body_f, fontSize: 14, color: OM.text, fontWeight: 600 }}>{r.label}</div>
              <div style={{ display: 'flex', gap: 4 }}>
                {Array.from({ length: 5 }).map((_, j) => (
                  <Icon
                    key={j}
                    name={j < r.value ? 'star' : 'star-o'}
                    size={22}
                    color={j < r.value ? '#FFC857' : 'rgba(20,20,40,0.22)'}
                  />
                ))}
              </div>
            </div>
          ))}
        </div>
        {/* comment */}
        <div style={{ padding: '0 22px 18px' }}>
          <div className="om-card" style={{ padding: 14, minHeight: 86 }}>
            <div style={{ fontSize: 13, color: OM.body, lineHeight: 1.45, fontWeight: 500 }}>
              Solid rolls tonight, good energy.
            </div>
            <div style={{ marginTop: 6, fontSize: 13, color: OM.faint, lineHeight: 1.45 }}>
              Share more about your experience (optional)…
            </div>
          </div>
        </div>
        {/* submit */}
        <div style={{ padding: '0 22px' }}>
          <PrimaryBtn full icon="check">Post Review</PrimaryBtn>
        </div>
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// 5. GYM DETAIL
// ─────────────────────────────────────────────────────────────
const ScreenGym = () => {
  const amenities = [
    { icon: 'parking', label: 'Parking' },
    { icon: 'shower',  label: 'Showers' },
    { icon: 'wifi',    label: 'WiFi' },
    { icon: 'door',    label: 'Changing' },
    { icon: 'shop',    label: 'Pro Shop' },
    { icon: 'water',   label: 'Water' },
  ];
  const upcoming = [
    { day: 'Tonight',  time: '7:00 PM', gi: 'gi' },
    { day: 'Sat',      time: '11:00 AM', gi: 'nogi' },
    { day: 'Sun',      time: '12:00 PM', gi: 'both' },
  ];
  return (
    <Phone hasNav={false} hasStatusReserve={false}>
      {/* hero banner — saturated brand gradient */}
      <div style={{
        height: 240, position: 'relative', overflow: 'hidden',
        background: `linear-gradient(135deg, ${OM.crimson} 0%, ${OM.both} 100%)`,
      }}>
        <svg width="100%" height="100%" style={{ position: 'absolute', inset: 0, opacity: 0.18 }} viewBox="0 0 400 240" preserveAspectRatio="xMidYMid slice">
          <defs>
            <pattern id="om-gym-tex" width="40" height="40" patternUnits="userSpaceOnUse" patternTransform="rotate(35)">
              <path d="M0 20H40" stroke="white" strokeWidth="0.6"/>
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#om-gym-tex)"/>
        </svg>
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to bottom, transparent 40%, rgba(40,20,60,0.55) 100%)' }} />
        <div style={{ position: 'absolute', left: 18, bottom: 60, fontFamily: OM.display, fontWeight: 900, fontSize: 140, color: 'rgba(255,255,255,0.20)', lineHeight: 1 }}>A</div>
        {/* top icons — glass over saturated bg */}
        <div style={{ position: 'absolute', top: 60, left: 16, right: 16, display: 'flex', justifyContent: 'space-between' }}>
          <div style={{
            width: 40, height: 40, borderRadius: 13,
            background: 'rgba(255,255,255,0.28)',
            backdropFilter: 'blur(16px) saturate(180%)', WebkitBackdropFilter: 'blur(16px) saturate(180%)',
            border: '1px solid rgba(255,255,255,0.35)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: 'inset 1.5px 1.5px 1px rgba(255,255,255,0.4)',
          }}>
            <Icon name="arrow-l" size={18} color="#fff" strokeWidth={2.5} />
          </div>
          <div style={{
            width: 40, height: 40, borderRadius: 13,
            background: 'rgba(255,255,255,0.28)',
            backdropFilter: 'blur(16px) saturate(180%)', WebkitBackdropFilter: 'blur(16px) saturate(180%)',
            border: '1px solid rgba(255,255,255,0.35)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: 'inset 1.5px 1.5px 1px rgba(255,255,255,0.4)',
          }}>
            <Icon name="heart-f" size={18} color="#fff" strokeWidth={2} />
          </div>
        </div>
        <div style={{ position: 'absolute', left: 18, right: 18, bottom: 18 }}>
          <div className="om-eyebrow" style={{ color: 'rgba(255,255,255,0.9)' }}>Established 2012 · Affiliate</div>
          <div className="om-h1" style={{ color: '#fff', fontSize: 30, marginTop: 4 }}>Atos HQ</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4, color: 'rgba(255,255,255,0.9)', fontSize: 13 }}>
            <Icon name="star" size={13} color="#FFC857" />
            <span className="om-num" style={{ color: '#fff' }}>4.8</span>
            <span>· 312 reviews · 1.2 mi</span>
          </div>
        </div>
      </div>

      {/* directions */}
      <div style={{ padding: '16px 18px 18px' }}>
        <div className="om-card" style={{ padding: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
            <Icon name="pin" size={16} color={OM.crimson} />
            <div style={{ flex: 1, fontSize: 13, color: OM.body, fontWeight: 500 }}>9587 Distribution Ave, San Diego CA 92121</div>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button style={{
              flex: 1, height: 44, borderRadius: 12, border: 'none', cursor: 'pointer',
              background: OM.crimson, color: '#fff',
              fontFamily: OM.display, fontWeight: 700, fontSize: 12, letterSpacing: 0.1, textTransform: 'uppercase',
              display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              boxShadow: `0 6px 16px ${OM.crimson}55`,
            }}>
              <Icon name="directions" size={15} color="#fff" strokeWidth={2.5} />
              Directions
            </button>
            <button style={{
              flex: 1, height: 44, borderRadius: 12, cursor: 'pointer',
              background: 'rgba(255,255,255,0.6)',
              backdropFilter: 'blur(16px)', WebkitBackdropFilter: 'blur(16px)',
              color: OM.text,
              border: `1px solid ${OM.borderDark}`,
              fontFamily: OM.display, fontWeight: 700, fontSize: 12, letterSpacing: 0.1, textTransform: 'uppercase',
              display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              boxShadow: 'inset 1px 1px 0 rgba(255,255,255,0.9)',
            }}>
              <Icon name="route" size={15} color={OM.gi} strokeWidth={2.5} />
              <span>Waze</span>
            </button>
          </div>
        </div>
      </div>

      {/* amenities */}
      <div style={{ padding: '0 18px 22px' }}>
        <div className="om-h2" style={{ color: OM.text, fontSize: 16, marginBottom: 10 }}>Amenities</div>
        <div style={{ display: 'flex', gap: 7, flexWrap: 'wrap' }}>
          {amenities.map((a, i) => (
            <span key={i} style={glassPill({
              display: 'inline-flex', alignItems: 'center', gap: 6,
              padding: '8px 12px', borderRadius: 999,
              color: OM.body, fontSize: 12, fontWeight: 600,
              boxShadow: 'inset 1px 1px 0 rgba(255,255,255,0.9), 0 2px 8px rgba(20,20,40,0.04)',
            })}>
              <Icon name={a.icon} size={14} color={OM.teal} strokeWidth={2.2} />
              {a.label}
            </span>
          ))}
        </div>
      </div>

      {/* upcoming */}
      <div style={{ padding: '0 18px 22px' }}>
        <div className="om-h2" style={{ color: OM.text, fontSize: 16, marginBottom: 10 }}>This Week's Open Mats</div>
        <div className="om-card" style={{ overflow: 'hidden' }}>
          {upcoming.map((u, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', padding: '14px 14px',
              borderBottom: i < upcoming.length - 1 ? `1px solid ${OM.borderDark}` : 'none',
              gap: 12,
            }}>
              <div style={{
                width: 44, height: 44, borderRadius: 12,
                background: { gi: OM.gi, nogi: OM.noGi, both: OM.both }[u.gi] + '22',
                border: `1px solid ${{ gi: OM.gi, nogi: OM.noGi, both: OM.both }[u.gi]}55`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <Icon name={{ gi: 'gi', nogi: 'shirt', both: 'swords' }[u.gi]} size={20} color={{ gi: OM.gi, nogi: OM.noGi, both: OM.both }[u.gi]} strokeWidth={2.5} />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span className="om-display" style={{ fontSize: 15, color: OM.text }}>{u.day}</span>
                  <GiBadge type={u.gi} size="sm" />
                </div>
                <div className="om-num" style={{ fontSize: 13, color: OM.muted, marginTop: 3 }}>{u.time}</div>
              </div>
              <Icon name="chevron-r" size={16} color={OM.muted} />
            </div>
          ))}
        </div>
      </div>

      {/* aggregate ratings */}
      <div style={{ padding: '0 18px 30px' }}>
        <div className="om-h2" style={{ color: OM.text, fontSize: 16, marginBottom: 10 }}>Mat Ratings</div>
        <div className="om-card" style={{ padding: '6px 16px' }}>
          <StarRow label="Gym Quality" value={4.9} dark={false} />
          <div style={{ height: 1, background: OM.borderDark }} />
          <StarRow label="Level Match" value={4.6} dark={false} />
          <div style={{ height: 1, background: OM.borderDark }} />
          <StarRow label="Cleanliness" value={4.9} dark={false} />
          <div style={{ height: 1, background: OM.borderDark }} />
          <StarRow label="Friendliness" value={4.8} dark={false} />
        </div>
      </div>
    </Phone>
  );
};

// ─────────────────────────────────────────────────────────────
// 6. GYM REGISTRATION WIZARD (Step 1)
// ─────────────────────────────────────────────────────────────
const ScreenRegister = () => {
  return (
    <Phone hasNav={false}>
      {/* top bar */}
      <div style={{ padding: '0 18px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={glassPill({ width: 40, height: 40, borderRadius: 13, display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
          <Icon name="close" size={18} color={OM.text} />
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span className="om-eyebrow" style={{ color: OM.muted }}>Step</span>
          <span className="om-num" style={{ color: OM.text, fontSize: 14 }}>1<span style={{ color: OM.muted }}> / 3</span></span>
        </div>
      </div>

      {/* progress */}
      <div style={{ padding: '0 18px 22px', display: 'flex', gap: 6 }}>
        {[1, 2, 3].map(n => (
          <div key={n} style={{
            flex: 1, height: 6, borderRadius: 99,
            background: n === 1 ? OM.crimson : 'rgba(20,20,40,0.08)',
            boxShadow: n === 1 ? `0 0 12px ${OM.crimson}55` : 'none',
          }} />
        ))}
      </div>

      {/* title */}
      <div style={{ padding: '0 18px 18px' }}>
        <div className="om-eyebrow" style={{ color: OM.crimson }}>Register Your Gym</div>
        <div className="om-h1" style={{ color: OM.text, fontSize: 28, marginTop: 4 }}>Basic Info</div>
        <div style={{ fontSize: 13, color: OM.muted, marginTop: 4, fontWeight: 500 }}>Help practitioners find you.</div>
      </div>

      {/* form */}
      <div style={{ padding: '0 18px 22px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {/* gym name */}
        <div>
          <div className="om-eyebrow" style={{ color: OM.muted, fontSize: 10, marginBottom: 6 }}>Gym Name</div>
          <div className="om-card" style={{
            height: 56, borderRadius: 16,
            display: 'flex', alignItems: 'center', padding: '0 14px',
            fontSize: 16, color: OM.text, fontWeight: 700,
          }}>Atos Jiu-Jitsu HQ</div>
        </div>
        {/* address autocomplete */}
        <div>
          <div className="om-eyebrow" style={{ color: OM.muted, fontSize: 10, marginBottom: 6 }}>Address</div>
          <div style={{
            borderRadius: 16,
            background: 'rgba(255,255,255,0.65)',
            backdropFilter: 'blur(20px) saturate(180%)',
            WebkitBackdropFilter: 'blur(20px) saturate(180%)',
            border: `1px solid ${OM.crimson}55`,
            overflow: 'hidden',
            boxShadow: `0 0 0 4px ${OM.crimson}11, inset 1.5px 1.5px 1px rgba(255,255,255,0.9), 0 8px 24px rgba(233,69,96,0.12)`,
          }}>
            <div style={{ height: 56, display: 'flex', alignItems: 'center', padding: '0 14px', gap: 10 }}>
              <Icon name="search" size={16} color={OM.crimson} />
              <span style={{ flex: 1, fontSize: 15, color: OM.text, fontWeight: 600 }}>9587 Distribution</span>
              <span style={{ width: 1, height: 22, background: OM.borderDark }} />
              <Icon name="pin" size={16} color={OM.muted} />
            </div>
            {/* suggestions */}
            <div style={{ background: 'rgba(255,255,255,0.55)', borderTop: `1px solid ${OM.borderDark}` }}>
              {[
                { main: '9587 Distribution Ave', sub: 'San Diego, CA 92121', highlight: true },
                { main: '9587 Distribution Way', sub: 'Vista, CA 92081' },
                { main: '9587 Distribution Blvd', sub: 'Los Angeles, CA 90015' },
              ].map((s, i) => (
                <div key={i} style={{
                  display: 'flex', alignItems: 'center', gap: 10,
                  padding: '12px 14px',
                  borderTop: i > 0 ? `1px solid ${OM.borderDark}` : 'none',
                  background: s.highlight ? OM.crimson + '15' : 'transparent',
                }}>
                  <Icon name="pin" size={14} color={s.highlight ? OM.crimson : OM.muted} />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 14, color: OM.text, fontWeight: 600 }}>{s.main}</div>
                    <div style={{ fontSize: 11, color: OM.muted, marginTop: 1 }}>{s.sub}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* confirmed chip */}
        <div style={{
          background: OM.teal + '18', border: `1px solid ${OM.teal}55`,
          backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)',
          borderRadius: 14, padding: '12px 14px',
          display: 'flex', alignItems: 'center', gap: 10,
          boxShadow: `0 4px 16px ${OM.teal}22`,
        }}>
          <div style={{ width: 28, height: 28, borderRadius: 99, background: OM.teal, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="check" size={16} color="#fff" strokeWidth={3} />
          </div>
          <div style={{ flex: 1 }}>
            <div className="om-eyebrow" style={{ color: OM.tealDeep, fontSize: 9 }}>Verified Location</div>
            <div style={{ fontSize: 13, color: OM.text, fontWeight: 600, marginTop: 2 }}>San Diego, CA · 32.901, -117.213</div>
          </div>
        </div>
      </div>

      {/* footer CTA */}
      <div style={{ marginTop: 'auto', padding: '14px 18px 18px',
        background: 'linear-gradient(to top, rgba(248,245,239,0.95) 60%, transparent)',
        backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)' }}>
        <PrimaryBtn full icon="arrow-r">Continue</PrimaryBtn>
      </div>
    </Phone>
  );
};

// ─────────────────────────────────────────────────────────────
// 7. CREATE OPEN MAT SESSION
// ─────────────────────────────────────────────────────────────
const ScreenCreate = () => {
  const giOptions = [
    { id: 'gi',   label: 'Gi',    icon: 'gi',     color: OM.gi },
    { id: 'nogi', label: 'No-Gi', icon: 'shirt',  color: OM.noGi },
    { id: 'both', label: 'Both',  icon: 'swords', color: OM.both, active: true },
  ];
  const expOpts = ['All Levels', 'Beginner', 'Intermediate', 'Advanced'];
  const activeExp = 'All Levels';
  return (
    <Phone hasNav={false}>
      {/* top bar */}
      <div style={{ padding: '0 18px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={glassPill({ width: 40, height: 40, borderRadius: 13, display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
          <Icon name="close" size={18} color={OM.text} />
        </div>
        <span className="om-eyebrow" style={{ color: OM.muted }}>Post Session</span>
        <div style={{ width: 40 }} />
      </div>

      <div style={{ padding: '0 18px 12px' }}>
        <div className="om-h1" style={{ color: OM.text, fontSize: 28 }}>New Open Mat</div>
      </div>

      {/* gym selector */}
      <div style={{ padding: '0 18px 12px' }}>
        <div className="om-card" style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 36, height: 36, borderRadius: 10, background: `linear-gradient(135deg, ${OM.crimson}, ${OM.both})`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontFamily: OM.display, fontWeight: 700, fontSize: 14 }}>A</div>
          <div style={{ flex: 1 }}>
            <div className="om-eyebrow" style={{ color: OM.muted, fontSize: 9 }}>Posting As</div>
            <div style={{ fontSize: 14, color: OM.text, fontWeight: 700, marginTop: 1 }}>Atos HQ — San Diego</div>
          </div>
          <Icon name="chevron-d" size={16} color={OM.muted} />
        </div>
      </div>

      {/* warning banner */}
      <div style={{ padding: '0 18px 14px' }}>
        <div style={{
          padding: '10px 14px', borderRadius: 12,
          background: OM.noGi + '18',
          backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)',
          border: `1px solid ${OM.noGi}55`,
          display: 'flex', alignItems: 'center', gap: 10,
          boxShadow: `0 4px 12px ${OM.noGi}22`,
        }}>
          <Icon name="bell" size={16} color={OM.noGi} />
          <div style={{ flex: 1, fontSize: 12, color: OM.body, lineHeight: 1.35, fontWeight: 500 }}>
            <span style={{ color: OM.noGi, fontWeight: 800 }}>1 of 2 sessions</span> already posted for this date.
          </div>
        </div>
      </div>

      {/* date + time */}
      <div style={{ padding: '0 18px 12px', display: 'flex', gap: 8 }}>
        <div className="om-card" style={{ flex: 1, padding: '12px 14px' }}>
          <div className="om-eyebrow" style={{ color: OM.muted, fontSize: 9 }}>Date</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4 }}>
            <Icon name="calendar" size={13} color={OM.crimson} />
            <span className="om-num" style={{ fontSize: 13, color: OM.text }}>Sat, Jun 7</span>
          </div>
        </div>
        <div className="om-card" style={{ flex: 1, padding: '12px 14px' }}>
          <div className="om-eyebrow" style={{ color: OM.muted, fontSize: 9 }}>Time</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4 }}>
            <Icon name="clock" size={13} color={OM.crimson} />
            <span className="om-num" style={{ fontSize: 13, color: OM.text }}>10–12 PM</span>
          </div>
        </div>
      </div>

      {/* gi type segmented */}
      <div style={{ padding: '0 18px 14px' }}>
        <div className="om-eyebrow" style={{ color: OM.muted, fontSize: 10, marginBottom: 8 }}>Gi Type</div>
        <div style={{ display: 'flex', gap: 8 }}>
          {giOptions.map(o => (
            <div key={o.id} style={{
              flex: 1, padding: '14px 0 12px', borderRadius: 14,
              background: o.active ? o.color + '22' : 'rgba(255,255,255,0.55)',
              backdropFilter: 'blur(16px) saturate(180%)', WebkitBackdropFilter: 'blur(16px) saturate(180%)',
              border: `1.5px solid ${o.active ? o.color : OM.borderDark}`,
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
              boxShadow: o.active
                ? `0 0 0 4px ${o.color}15, inset 1px 1px 0 rgba(255,255,255,0.9), 0 8px 20px ${o.color}33`
                : 'inset 1px 1px 0 rgba(255,255,255,0.9), 0 4px 12px rgba(20,20,40,0.04)',
            }}>
              <Icon name={o.icon} size={22} color={o.active ? o.color : OM.muted} strokeWidth={2.5} />
              <span style={{ fontFamily: OM.display, fontWeight: 700, fontSize: 11, letterSpacing: 0.1, textTransform: 'uppercase', color: o.active ? o.color : OM.body }}>{o.label}</span>
            </div>
          ))}
        </div>
      </div>

      {/* experience */}
      <div style={{ padding: '0 18px 14px' }}>
        <div className="om-eyebrow" style={{ color: OM.muted, fontSize: 10, marginBottom: 8 }}>Experience Level</div>
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {expOpts.map(e => {
            const active = e === activeExp;
            return (
              <span key={e} style={{
                padding: '8px 14px', borderRadius: 999,
                background: active ? OM.crimson + '22' : 'rgba(255,255,255,0.55)',
                backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)',
                border: `1px solid ${active ? OM.crimson : OM.borderDark}`,
                color: active ? OM.crimson : OM.body,
                fontFamily: OM.display, fontWeight: 700, fontSize: 11, letterSpacing: 0.1, textTransform: 'uppercase',
                boxShadow: active ? `0 4px 12px ${OM.crimson}22` : 'inset 1px 1px 0 rgba(255,255,255,0.9)',
              }}>{e}</span>
            );
          })}
        </div>
      </div>

      {/* mat fee */}
      <div style={{ padding: '0 18px 14px' }}>
        <div className="om-card" style={{ padding: 14, display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 36, height: 36, borderRadius: 10, background: OM.teal + '22', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="gift" size={18} color={OM.teal} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, color: OM.text, fontWeight: 700 }}>Free Mat</div>
            <div style={{ fontSize: 11, color: OM.muted, marginTop: 1, fontWeight: 500 }}>Drop-in welcome, no charge</div>
          </div>
          {/* toggle on */}
          <div style={{ width: 50, height: 28, borderRadius: 99, background: OM.teal, position: 'relative', boxShadow: `0 4px 12px ${OM.teal}55, inset 0 1px 0 rgba(255,255,255,0.3)` }}>
            <div style={{ position: 'absolute', right: 2, top: 2, width: 24, height: 24, borderRadius: 99, background: '#fff', boxShadow: '0 2px 4px rgba(0,0,0,0.25)' }} />
          </div>
        </div>
      </div>

      {/* notes */}
      <div style={{ padding: '0 18px 14px' }}>
        <div className="om-eyebrow" style={{ color: OM.muted, fontSize: 10, marginBottom: 8 }}>Notes (optional)</div>
        <div className="om-card" style={{ padding: 14, minHeight: 64, fontSize: 13, color: OM.body, lineHeight: 1.45, fontWeight: 500 }}>
          Visitors welcome. Bring both gi and rashguard.
        </div>
      </div>

      {/* CTA */}
      <div style={{ padding: '8px 18px 18px' }}>
        <PrimaryBtn full icon="plus">Post Session</PrimaryBtn>
      </div>
    </Phone>
  );
};

// ─────────────────────────────────────────────────────────────
// 8. PROFILE
// ─────────────────────────────────────────────────────────────
const ScreenProfile = () => {
  const sessions = SESSIONS.slice(0, 2);
  const favs = [
    { name: 'Atos HQ', sub: 'San Diego · 1.2 mi' },
    { name: 'Gracie Barra DTLA', sub: 'Los Angeles · 2.4 mi' },
    { name: '10th Planet Rosemead', sub: 'Rosemead · 4.1 mi' },
  ];
  return (
    <Phone>
      {/* hero */}
      <div style={{ padding: '0 18px 16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
          <div className="om-h1" style={{ color: OM.text }}>Profile</div>
          <div style={{ display: 'flex', gap: 8 }}>
            <div style={glassPill({ width: 38, height: 38, borderRadius: 13, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' })}>
              <Icon name="bell" size={16} color={OM.text} />
              <div style={{ position: 'absolute', top: 7, right: 7, width: 8, height: 8, borderRadius: 99, background: OM.crimson, border: `1.5px solid #fff` }} />
            </div>
            <div style={glassPill({ width: 38, height: 38, borderRadius: 13, display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
              <Icon name="settings" size={16} color={OM.text} />
            </div>
          </div>
        </div>

        {/* avatar card */}
        <div style={{
          padding: '20px 18px',
          background: `linear-gradient(135deg, ${OM.crimson}33 0%, rgba(255,255,255,0.65) 60%)`,
          backdropFilter: 'blur(24px) saturate(180%)', WebkitBackdropFilter: 'blur(24px) saturate(180%)',
          border: `1px solid ${OM.borderDark}`,
          borderRadius: 22,
          display: 'flex', alignItems: 'center', gap: 14,
          position: 'relative', overflow: 'hidden',
          boxShadow: 'inset 1.5px 1.5px 1px rgba(255,255,255,0.95), 0 12px 32px rgba(233,69,96,0.18)',
        }}>
          <div style={{ position: 'absolute', top: -30, right: -30, width: 160, height: 160, borderRadius: 99, background: `radial-gradient(circle, ${OM.crimson}55, transparent 70%)`, filter: 'blur(24px)' }} />
          <div style={{
            width: 72, height: 72, borderRadius: 99,
            background: `linear-gradient(135deg, ${OM.crimson}, ${OM.both})`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', fontFamily: OM.display, fontWeight: 700, fontSize: 28,
            boxShadow: `0 0 0 3px #fff, 0 0 0 5px ${OM.crimson}88, 0 8px 20px rgba(233,69,96,0.4)`,
          }}>MR</div>
          <div style={{ flex: 1, position: 'relative', zIndex: 1 }}>
            <div className="om-h1" style={{ fontSize: 22, color: OM.text }}>Mateo Reyes</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
              <BeltBadge belt="purple" stripes={2} size="sm" />
            </div>
            <div style={{ display: 'flex', gap: 12, marginTop: 10 }}>
              <div><span className="om-num" style={{ color: OM.text, fontSize: 16 }}>27</span> <span style={{ color: OM.muted, fontSize: 11, fontWeight: 600 }}>mats</span></div>
              <div><span className="om-num" style={{ color: OM.text, fontSize: 16 }}>8</span> <span style={{ color: OM.muted, fontSize: 11, fontWeight: 600 }}>reviews</span></div>
            </div>
          </div>
        </div>
      </div>

      {/* My Sessions */}
      <div style={{ padding: '0 18px 22px' }}>
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginBottom: 10 }}>
          <div className="om-h2" style={{ color: OM.text, fontSize: 17 }}>My Sessions</div>
          <span className="om-eyebrow" style={{ color: OM.crimson }}>See all</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {sessions.map(s => <SessionCard key={s.id} session={s} compact />)}
        </div>
      </div>

      {/* Favorite Gyms */}
      <div style={{ padding: '0 18px 22px' }}>
        <div className="om-h2" style={{ color: OM.text, fontSize: 17, marginBottom: 10 }}>Favorite Gyms</div>
        <div className="om-card" style={{ overflow: 'hidden' }}>
          {favs.map((f, i) => (
            <div key={i} style={{
              padding: '14px 14px', display: 'flex', alignItems: 'center', gap: 12,
              borderBottom: i < favs.length - 1 ? `1px solid ${OM.borderDark}` : 'none',
            }}>
              <div style={{ width: 36, height: 36, borderRadius: 10, background: OM.crimson + '15', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name="heart-f" size={16} color={OM.crimson} strokeWidth={2} />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 14, color: OM.text, fontWeight: 700 }}>{f.name}</div>
                <div style={{ fontSize: 11, color: OM.muted, marginTop: 1, fontWeight: 500 }}>{f.sub}</div>
              </div>
              <Icon name="chevron-r" size={14} color={OM.muted} />
            </div>
          ))}
        </div>
      </div>

      {/* Settings */}
      <div style={{ padding: '0 18px 30px' }}>
        <div className="om-h2" style={{ color: OM.text, fontSize: 17, marginBottom: 10 }}>Settings</div>
        <div className="om-card" style={{ overflow: 'hidden' }}>
          {[
            { icon: 'moon',     label: 'Light theme',    trail: 'On' },
            { icon: 'bell',     label: 'Notifications',  trail: '3 active' },
            { icon: 'settings', label: 'Account',        trail: '' },
            { icon: 'logout',   label: 'Sign out',       trail: '', danger: true },
          ].map((row, i, arr) => (
            <div key={i} style={{
              padding: '14px 14px', display: 'flex', alignItems: 'center', gap: 12,
              borderBottom: i < arr.length - 1 ? `1px solid ${OM.borderDark}` : 'none',
            }}>
              <Icon name={row.icon} size={18} color={row.danger ? OM.crimson : OM.muted} />
              <div style={{ flex: 1, fontSize: 14, color: row.danger ? OM.crimson : OM.text, fontWeight: 600 }}>{row.label}</div>
              {row.trail && <span style={{ fontSize: 12, color: OM.muted, fontWeight: 500 }}>{row.trail}</span>}
              <Icon name="chevron-r" size={14} color={OM.muted} />
            </div>
          ))}
        </div>
      </div>

      <BottomNav active="profile" />
    </Phone>
  );
};

Object.assign(window, {
  ScreenHome, ScreenSearch, ScreenDetail, ScreenReview,
  ScreenGym, ScreenRegister, ScreenCreate, ScreenProfile,
});
