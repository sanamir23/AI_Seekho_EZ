// screen4-confirm.jsx — Booking Confirmation

function ConfirmScreen({ onTrack, onHome }) {
  return (
    <ScreenChrome bg="var(--ez-cream)">
      {/* Confetti layer */}
      <Confetti/>

      {/* Top close */}
      <div style={{ padding:'8px 18px', display:'flex', justifyContent:'flex-end', zIndex:5, position:'relative' }}>
        <button style={{
          width:32, height:32, borderRadius:999, background:'#fff',
          border:'1px solid var(--ez-border)',
          display:'grid', placeItems:'center', boxShadow:'var(--ez-shadow-sm)',
        }}>{Icon.close('#141414',14)}</button>
      </div>

      {/* Success burst */}
      <div style={{ display:'flex', flexDirection:'column', alignItems:'center', padding:'12px 24px 0', position:'relative', zIndex:5 }}>
        <div style={{
          position:'relative', width:120, height:120, marginTop:6,
        }}>
          {/* outer halo */}
          <div style={{
            position:'absolute', inset:0, borderRadius:999,
            background:'radial-gradient(circle at center, rgba(252,210,74,.5), transparent 70%)',
            animation:'ez-burst .8s ease both',
          }}/>
          {/* mid ring */}
          <div style={{
            position:'absolute', inset:18, borderRadius:999,
            background:'var(--ez-yellow-soft)',
            animation:'ez-burst .8s ease .08s both',
          }}/>
          {/* check disk */}
          <div style={{
            position:'absolute', inset:30, borderRadius:999,
            background:'linear-gradient(135deg, var(--ez-yellow), var(--ez-yellow-deep))',
            display:'grid', placeItems:'center',
            boxShadow:'0 10px 30px rgba(232,182,23,.45)',
            animation:'ez-burst .6s cubic-bezier(.4,1.6,.5,1) .15s both',
          }}>
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none">
              <path d="M5 12l4.5 4.5L19 7"
                stroke="#141414" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"
                strokeDasharray="24" strokeDashoffset="24"
                style={{ animation:'ez-tick-in .5s ease .35s forwards' }}/>
            </svg>
          </div>
          {/* sparkle dots */}
          {[
            {x:-4,y:8},{x:108,y:14},{x:-2,y:88},{x:104,y:92},{x:54,y:-8},{x:54,y:118}
          ].map((p,i)=>(
            <span key={i} style={{
              position:'absolute', left:p.x, top:p.y,
              width:8, height:8, borderRadius:99,
              background: i%2 ? 'var(--ez-ink)' : 'var(--ez-yellow-deep)',
              animation:`ez-burst .5s ease ${.4 + i*.05}s both`,
            }}/>
          ))}
        </div>

        <h1 style={{
          margin:'18px 0 4px', fontFamily:'var(--ez-display)',
          fontSize:26, fontWeight:600, letterSpacing:'-0.02em', textAlign:'center',
          animation:'ez-fade-up .5s ease .3s both',
        }}>Booking confirmed!</h1>
        <p style={{
          margin:0, fontSize:13, color:'var(--ez-ink-soft)', textAlign:'center', maxWidth:240,
          animation:'ez-fade-up .5s ease .4s both', lineHeight:1.4,
        }}>
          <b>Asad Mehmood</b> will see you tomorrow at <b>9:30 AM</b>. Aap fikr na karein.
        </p>
      </div>

      {/* Summary card */}
      <div style={{ padding:'18px 16px 0', position:'relative', zIndex:5,
        animation:'ez-fade-up .5s ease .5s both' }}>
        <div style={{
          background:'#fff', borderRadius:20, padding:'14px',
          border:'1px solid var(--ez-border)',
          boxShadow:'var(--ez-shadow-md)',
        }}>
          <div style={{ display:'flex', alignItems:'center', gap:12, paddingBottom:12,
            borderBottom:'1px dashed var(--ez-border)',
          }}>
            <div style={{
              width:48, height:48, borderRadius:14,
              background:'linear-gradient(135deg, #FCD24A, #FFE988)',
              display:'grid', placeItems:'center',
              border:'1px solid var(--ez-border-soft)',
              fontFamily:'var(--ez-display)', fontWeight:700, fontSize:18,
            }}>AM</div>
            <div style={{ flex:1 }}>
              <div style={{ fontSize:14, fontWeight:800, display:'flex', alignItems:'center', gap:5 }}>
                Asad Mehmood {Icon.shield('var(--ez-info)',12)}
              </div>
              <div style={{ fontSize:11.5, color:'var(--ez-muted)', fontWeight:600, display:'flex', alignItems:'center', gap:4, marginTop:1 }}>
                {Icon.star('var(--ez-yellow-deep)', true, 11)} 4.9 · CoolFix HVAC Pros
              </div>
            </div>
            <span style={{
              fontSize:9.5, fontWeight:800, padding:'3px 7px', borderRadius:6,
              background:'var(--ez-yellow-glow)', border:'1px solid var(--ez-yellow)',
              color:'var(--ez-ink-soft)',
            }}>AI PICK</span>
          </div>

          {[
            { k:'Service', v:'AC Repair · Split Unit' },
            { k:'When', v:'Tomorrow · 9:30 AM' },
            { k:'Where', v:'House 12, St. 7, G-13/3' },
            { k:'Total', v:'₨1,500 – 2,500', emph:true },
          ].map((r,i)=>(
            <div key={i} style={{
              display:'flex', justifyContent:'space-between', alignItems:'baseline',
              padding:'8px 0', borderBottom: i<3 ? '1px solid var(--ez-border-soft)' : 'none',
            }}>
              <span style={{ fontSize:11.5, color:'var(--ez-muted)', fontWeight:600 }}>{r.k}</span>
              <span style={{ fontSize: r.emph?14:12.5, fontWeight: r.emph?800:700, color:'var(--ez-ink)' }}>{r.v}</span>
            </div>
          ))}
        </div>

        {/* Reminder confirmation */}
        <div style={{
          marginTop:12, display:'flex', alignItems:'center', gap:10,
          padding:'10px 12px', borderRadius:14,
          background:'var(--ez-success-soft)', border:'1px solid #BBF7D0',
          animation:'ez-fade-up .5s ease .6s both',
        }}>
          <div style={{
            width:28, height:28, borderRadius:8, background:'var(--ez-success)',
            display:'grid', placeItems:'center',
          }}>{Icon.bell('#fff',16)}</div>
          <div style={{ flex:1 }}>
            <div style={{ fontSize:12, fontWeight:800, color:'#166534' }}>Reminder set</div>
            <div style={{ fontSize:10.5, color:'#15803D', fontWeight:600 }}>
              We'll ping you 1 hour before — Bas tension free raho.
            </div>
          </div>
          {Icon.check('#166534', 14)}
        </div>
      </div>

      {/* CTAs */}
      <div style={{
        position:'relative', zIndex:5, marginTop:'auto',
        padding:'16px 16px 28px', display:'flex', gap:10,
        animation:'ez-fade-up .5s ease .7s both',
      }}>
        <PillBtn full variant="primary" onClick={onTrack} style={{ flex:2 }}>
          Track Provider
        </PillBtn>
        <PillBtn variant="soft" onClick={onHome} style={{ flex:1 }}>
          Go Home
        </PillBtn>
      </div>
    </ScreenChrome>
  );
}

// Confetti animation in front of header
function Confetti() {
  // Deterministic positions so it's predictable
  const pieces = React.useMemo(() => {
    const colors = ['#FCD24A','#141414','#E8B617','#FFE988','#FFFAE0'];
    const shapes = ['rect','circle','tri'];
    return Array.from({length: 28}, (_,i)=>({
      left: (i * 37) % 100, // %
      delay: (i % 10) * 0.15,
      dur: 2.4 + (i % 5) * 0.35,
      rot: (i*31) % 360,
      size: 6 + (i%4)*2,
      color: colors[i%colors.length],
      shape: shapes[i%3],
    }));
  }, []);
  return (
    <div style={{
      position:'absolute', top:0, left:0, right:0, height:380,
      pointerEvents:'none', zIndex:3, overflow:'hidden',
    }}>
      {pieces.map((p,i)=>(
        <span key={i} style={{
          position:'absolute', left:`${p.left}%`, top:-12,
          width:p.size, height:p.shape==='rect'?p.size*1.3:p.size,
          background: p.color,
          borderRadius: p.shape==='circle'?'50%': p.shape==='tri'?0:2,
          clipPath: p.shape==='tri' ? 'polygon(50% 0, 100% 100%, 0 100%)' : 'none',
          transform:`rotate(${p.rot}deg)`,
          animation:`ez-confetti-fall ${p.dur}s cubic-bezier(.2,.6,.4,1) ${p.delay}s infinite`,
          opacity:0,
        }}/>
      ))}
    </div>
  );
}

Object.assign(window, { ConfirmScreen });
