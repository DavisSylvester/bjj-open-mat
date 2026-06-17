// kit.jsx — Component Kit panels (light + dark variants)

// Kit variants both use the light glass system now; the `variant` prop only
// affects the underlying canvas color so the glass blur reads differently.
const KitCard = ({ title, variant = 'cream', children, height }) => {
  const text = OM.text;
  const muted = OM.muted;
  return (
    <div style={{
      background: 'transparent', borderRadius: 20, padding: 22,
      fontFamily: OM.body_f, color: text,
      height,
      display: 'flex', flexDirection: 'column', gap: 14,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div className="om-h2" style={{ color: text, fontSize: 17 }}>{title}</div>
        <span className="om-eyebrow" style={{ color: muted, fontSize: 10 }}>{variant === 'gradient' ? 'On Gradient' : 'On Cream'}</span>
      </div>
      <div style={{ height: 1, background: OM.borderDark }} />
      {children}
    </div>
  );
};

const KitSection = ({ label, children }) => (
  <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
    <div className="om-eyebrow" style={{ color: OM.muted, fontSize: 10 }}>{label}</div>
    {children}
  </div>
);

// ─────────────────────────────────────────────────────────────
// Brand foundations card
// ─────────────────────────────────────────────────────────────
const KitFoundations = () => {
  const palette = [
    { name: 'Canvas',     val: OM.bg },
    { name: 'Glass White',val: '#FFFFFF' },
    { name: 'Ink',        val: OM.text },
    { name: 'Crimson',    val: OM.crimson },
    { name: 'Teal',       val: OM.teal },
    { name: 'Gi Blue',    val: OM.gi },
    { name: 'No-Gi Amber',val: OM.noGi },
    { name: 'Both Purple',val: OM.both },
  ];
  return (
    <div style={{
      background: OM.bgGradient,
      borderRadius: 20, padding: 26,
      border: `1px solid ${OM.borderDark}`,
      color: OM.text, fontFamily: OM.body_f,
      display: 'flex', flexDirection: 'column', gap: 22,
    }}>
      <div>
        <div className="om-eyebrow" style={{ color: OM.crimson }}>Open Mat — Light Glass System</div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 16, marginTop: 4 }}>
          <div className="om-display" style={{ fontSize: 64, color: OM.text, lineHeight: 0.9 }}>Foundations</div>
        </div>
        <div style={{ fontSize: 14, color: OM.body, marginTop: 8, maxWidth: 540, fontWeight: 500 }}>
          Translucent white surfaces over a warm pastel gradient — crimson, lavender, mint, sky. Glass blur reveals the color underneath. Tone: athletic, focused, welcoming.
        </div>
      </div>

      {/* type */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
        <div className="om-card" style={{ padding: 18 }}>
          <div className="om-eyebrow" style={{ color: OM.muted }}>Display · Barlow Condensed</div>
          <div className="om-h1" style={{ color: OM.text, fontSize: 42, marginTop: 6 }}>Roll Tonight</div>
          <div className="om-h2" style={{ color: OM.body, fontSize: 18, marginTop: 4 }}>Open Mat Headline</div>
        </div>
        <div className="om-card" style={{ padding: 18 }}>
          <div className="om-eyebrow" style={{ color: OM.muted }}>Body · Barlow</div>
          <div style={{ fontFamily: OM.body_f, fontWeight: 700, fontSize: 16, color: OM.text, marginTop: 6 }}>Drop-in mats, every belt.</div>
          <div style={{ fontFamily: OM.body_f, fontWeight: 500, fontSize: 13, color: OM.body, marginTop: 6, lineHeight: 1.5 }}>
            Body copy is clean, generous, and quietly confident — never aggressive. 14px is the default reading size.
          </div>
        </div>
      </div>

      {/* palette */}
      <div>
        <div className="om-eyebrow" style={{ color: OM.muted, marginBottom: 10 }}>Palette</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(8, 1fr)', gap: 8 }}>
          {palette.map((p, i) => (
            <div key={i} className="om-card" style={{ borderRadius: 12, overflow: 'hidden', padding: 0 }}>
              <div style={{ height: 56, background: p.val }} />
              <div style={{ padding: '8px 10px' }}>
                <div style={{ fontSize: 10, color: OM.text, fontWeight: 700 }}>{p.name}</div>
                <div className="om-mono" style={{ fontSize: 9, color: OM.muted, marginTop: 1 }}>{p.val.toUpperCase()}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Component kit card (variant by dark/light)
// ─────────────────────────────────────────────────────────────
const KitComponents = ({ variant = 'cream' }) => {
  const sample = SESSIONS[0];
  return (
    <KitCard title="Components" variant={variant} height="auto">
      {/* Gi Type Badge */}
      <KitSection label="Gi Type Badge">
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <GiBadge type="gi" />
          <GiBadge type="nogi" />
          <GiBadge type="both" />
        </div>
      </KitSection>

      {/* Experience Badge */}
      <KitSection label="Experience Badge">
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <ExpBadge level="all" />
          <ExpBadge level="beg" />
          <ExpBadge level="int" />
          <ExpBadge level="adv" />
        </div>
      </KitSection>

      {/* Belt Rank */}
      <KitSection label="Belt Rank Badge">
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
          <BeltBadge belt="white" stripes={0} />
          <BeltBadge belt="blue" stripes={2} />
          <BeltBadge belt="purple" stripes={3} />
          <BeltBadge belt="brown" stripes={1} />
          <BeltBadge belt="black" stripes={0} />
        </div>
      </KitSection>

      {/* Category Star Row */}
      <KitSection label="Category Star Row">
        <div className="om-card" style={{ padding: '4px 14px' }}>
          <StarRow label="Cleanliness" value={4.9} count={84} dark={false} />
          <div style={{ height: 1, background: OM.borderDark }} />
          <StarRow label="Friendliness" value={4.0} dark={false} interactive />
        </div>
      </KitSection>

      {/* Session card */}
      <KitSection label="Session Card">
        <SessionCard session={sample} />
      </KitSection>

      {/* Empty + shimmer */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <KitSection label="Empty State">
          <div className="om-card" style={{ overflow: 'hidden' }}>
            <EmptyState
              icon="mat"
              title="No mats nearby"
              subtitle="Widen your search radius or check back tomorrow."
              cta="Adjust filters"
              dark={false}
            />
          </div>
        </KitSection>
        <KitSection label="Loading Shimmer">
          <ShimmerCard />
          <div style={{ marginTop: 8 }}>
            <ShimmerCard />
          </div>
        </KitSection>
      </div>
    </KitCard>
  );
};

Object.assign(window, { KitFoundations, KitComponents });
