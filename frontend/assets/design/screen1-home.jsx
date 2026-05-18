// screen1-home.jsx — EZ home/input screen
// Uses Icon, Chip, PillBtn, AmbientHomes from design-system.jsx

// Common header for non-search screens
function ScreenChrome({ children, bg = 'var(--ez-cream)' }) {
  return (
    <div className="ez-app" style={{
      width: '100%', height: '100%', background: bg,
      paddingTop: 54, // status bar
      position: 'relative', overflow: 'hidden',
      display: 'flex', flexDirection: 'column'
    }}>
      {children}
    </div>);

}

// ─────────────────────────────────────────────────────────────
// SCREEN 1 — Home / Input
// ─────────────────────────────────────────────────────────────
function HomeScreen({ onSearch }) {
  return (
    <ScreenChrome>
      {/* Ambient backdrop */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 240, zIndex: 0 }}>
        <AmbientHomes opacity={.55} />
        <div style={{
          position: 'absolute', inset: 0,
          background: 'linear-gradient(180deg, transparent 50%, var(--ez-cream) 100%)'
        }} />
      </div>

      {/* Header: location pill + bell */}
      <div style={{ position: 'relative', zIndex: 2, padding: '10px 18px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between'
      }}>
        <button style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '7px 12px 7px 9px', borderRadius: 999,
          background: '#fff', border: '1px solid var(--ez-border)',
          boxShadow: 'var(--ez-shadow-sm)'
        }}>
          {Icon.pin('#141414', 13)}
          <span style={{ fontSize: 12.5, fontWeight: 700 }}>G-13, Islamabad</span>
          {Icon.chevDown('#8B8576', 12)}
        </button>
        <div style={{ display: 'flex', gap: 8 }}>
          <button style={{
            width: 36, height: 36, borderRadius: 999, background: '#fff',
            border: '1px solid var(--ez-border)', display: 'grid', placeItems: 'center',
            boxShadow: 'var(--ez-shadow-sm)', position: 'relative'
          }}>
            {Icon.bell('#141414', 18)}
            <span style={{
              position: 'absolute', top: 8, right: 8, width: 7, height: 7,
              borderRadius: 99, background: 'var(--ez-yellow-deep)', border: '1.5px solid #fff'
            }} />
          </button>
          <div style={{
            width: 36, height: 36, borderRadius: 999,
            background: 'linear-gradient(135deg, #FCD24A, #E8B617)',
            display: 'grid', placeItems: 'center',
            color: '#141414', fontWeight: 800, fontSize: 13,
            border: '2px solid #fff', boxShadow: 'var(--ez-shadow-sm)'
          }}>A</div>
        </div>
      </div>

      {/* Greeting */}
      <div style={{ position: 'relative', zIndex: 2, padding: '14px 20px 4px' }}>
        <div style={{ fontSize: 13, color: 'var(--ez-ink-soft)', fontWeight: 500 }}>
          Assalam-o-Alaikum, <span style={{ fontWeight: 700, color: 'var(--ez-ink)' }}>Ahmad</span>
        </div>
        <h1 style={{
          margin: '6px 0 0', fontFamily: 'var(--ez-display)',
          fontSize: 26, lineHeight: 1.1, fontWeight: 600,
          letterSpacing: '-0.02em', color: 'var(--ez-ink)'
        }}>
          How can we assist<br />you today?
        </h1>
      </div>

      {/* Big search bar */}
      <div style={{ position: 'relative', zIndex: 2, padding: '18px 16px 8px' }}>
        <button onClick={onSearch} style={{
          width: '100%', display: 'flex', alignItems: 'center', gap: 10,
          padding: '14px 12px 14px 16px', borderRadius: 18, background: '#fff',
          border: '1px solid var(--ez-border)', textAlign: 'left',
          boxShadow: '0 1px 2px rgba(20,20,20,.04), 0 12px 28px rgba(20,20,20,.08)'
        }}>
          <div style={{
            width: 34, height: 34, borderRadius: 12, background: 'var(--ez-yellow)',
            display: 'grid', placeItems: 'center', flexShrink: 0, textAlign: "center"
          }}>{Icon.sparkle('#141414', 16)}</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13.5, color: 'var(--ez-ink)', fontWeight: 600, lineHeight: 1.2 }}>
              Apko konsi service chahiyay?
            </div>
            <div style={{ fontSize: 11.5, color: 'var(--ez-muted)', marginTop: 2 }}>
              Type or say it — Urdu, English, Roman
            </div>
          </div>
          <div style={{
            width: 34, height: 34, borderRadius: 999, background: '#fff',
            border: '1px solid var(--ez-border)',
            display: 'grid', placeItems: 'center', flexShrink: 0
          }}>{Icon.mic('#141414', 16)}</div>
          <div style={{
            width: 38, height: 38, borderRadius: 999, background: 'var(--ez-ink)',
            display: 'grid', placeItems: 'center', flexShrink: 0,
            boxShadow: '0 4px 12px rgba(20,20,20,.18)'
          }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
              <path d="M5 12h14M13 6l6 6-6 6" stroke="#FCD24A" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
        </button>
      </div>

      {/* Quick service chips */}
      <div style={{ position: 'relative', zIndex: 2 }}>
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '14px 20px 8px'
        }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--ez-ink)' }}>Quick services</div>
          <div style={{ fontSize: 11.5, color: 'var(--ez-muted)', fontWeight: 600 }}>See all</div>
        </div>
        <div className="ez-no-scroll" style={{
          display: 'flex', gap: 8, overflowX: 'auto', padding: '0 16px 4px'
        }}>
          {[
          { i: Icon.ac('#141414', 14), l: 'AC Repair' },
          { i: Icon.wrench('#141414', 14), l: 'Plumber' },
          { i: Icon.bolt('#141414', 14), l: 'Electrician' },
          { i: Icon.book('#141414', 14), l: 'Tutor' },
          { i: Icon.scissors('#141414', 14), l: 'Beautician' },
          { i: Icon.broom('#141414', 14), l: 'Cleaning' }].
          map((c, i) =>
          <Chip key={i} icon={c.i} label={c.l} active={i === 0} />
          )}
        </div>
      </div>

      {/* Popular near you cards */}
      <div style={{ position: 'relative', zIndex: 2, padding: '18px 16px 8px', flex: 1, minHeight: 0 }}>
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10
        }}>
          <div style={{ fontSize: 13, fontWeight: 700 }}>Popular near you</div>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 4,
            fontSize: 10.5, fontWeight: 700, color: 'var(--ez-ink-soft)',
            padding: '3px 7px', borderRadius: 999, background: 'var(--ez-yellow-glow)',
            border: '1px solid var(--ez-yellow)'
          }}>
            {Icon.sparkle('#141414', 10)} AI ranked
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {[
          { t: 'AC Service', s: 'from ₨1,500', tag: 'Today', color: '#FCD24A' },
          { t: 'Plumbing', s: 'from ₨800', tag: '2hr ETA', color: '#FFE988' },
          { t: 'Deep Clean', s: 'from ₨3,500', tag: 'Tomorrow', color: '#F4EFE2' },
          { t: 'Maths Tutor', s: 'from ₨1,200/hr', tag: 'Verified', color: '#FFF5C2' }].
          map((c, i) =>
          <div key={i} style={{
            background: '#fff', border: '1px solid var(--ez-border)',
            borderRadius: 16, padding: '10px 12px 12px',
            boxShadow: 'var(--ez-shadow-sm)'
          }}>
              <div style={{
              width: 36, height: 36, borderRadius: 10, background: c.color,
              display: 'grid', placeItems: 'center', marginBottom: 8
            }}>
                {[Icon.ac, Icon.wrench, Icon.broom, Icon.book][i]('#141414', 18)}
              </div>
              <div style={{ fontSize: 12.5, fontWeight: 700 }}>{c.t}</div>
              <div style={{ fontSize: 11, color: 'var(--ez-muted)', marginTop: 2 }}>{c.s}</div>
              <div style={{
              marginTop: 8, display: 'inline-block',
              fontSize: 9.5, fontWeight: 700, padding: '2px 6px', borderRadius: 999,
              background: 'var(--ez-cream-2)', color: 'var(--ez-ink-soft)',
              textTransform: 'uppercase', letterSpacing: '0.04em'
            }}>{c.tag}</div>
            </div>
          )}
        </div>
      </div>

      {/* Bottom tab bar */}
      <BottomTabs active="home" />
    </ScreenChrome>);

}

// Shared bottom tab bar
function BottomTabs({ active = 'home' }) {
  const tab = (key, icon, label) => {
    const on = active === key;
    return (
      <div key={key} style={{
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
        flex: 1, opacity: on ? 1 : .55
      }}>
        {icon('#141414', 22)}
        <div style={{ fontSize: 10, fontWeight: on ? 700 : 600 }}>{label}</div>
        {on && <div style={{ width: 14, height: 2, borderRadius: 2, background: 'var(--ez-yellow-deep)', marginTop: 1 }} />}
      </div>);

  };
  return (
    <div style={{
      position: 'relative', zIndex: 3, marginTop: 'auto',
      paddingBottom: 24
    }}>
      <div style={{
        margin: '0 14px', background: '#fff', borderRadius: 24,
        border: '1px solid var(--ez-border)',
        boxShadow: '0 -2px 6px rgba(20,20,20,.03), 0 12px 24px rgba(20,20,20,.06)',
        display: 'flex', padding: '10px 8px'
      }}>
        {tab('home', Icon.home, 'Home')}
        {tab('bookings', Icon.bag, 'Bookings')}
        {tab('chat', Icon.msg, 'Chat')}
        {tab('me', Icon.user, 'Profile')}
      </div>
    </div>);

}

Object.assign(window, { HomeScreen, ScreenChrome, BottomTabs });