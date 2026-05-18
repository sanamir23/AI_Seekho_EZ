// screen2-thinking.jsx — AI Agent Reasoning (HERO screen)

const STEPS = [
  { key:'understand', icon: Icon.brain, title:'Understanding request', sub:'AC Technician · G-13 · Tomorrow morning', flair:'parse' },
  { key:'scan', icon: Icon.radar, title:'Scanning nearby providers', sub:'24 verified pros within 5 km', flair:'radar' },
  { key:'rate', icon: Icon.star, title:'Checking ratings & reviews', sub:'Filtered to 4.5★ and above', flair:'stars' },
  { key:'price', icon: Icon.coin, title:'Comparing prices', sub:'Range: ₨1,200 – ₨3,800', flair:'price' },
  { key:'avail', icon: Icon.cal, title:'Checking availability', sub:'Morning slots, 9 AM – 12 PM', flair:'cal' },
  { key:'pick', icon: Icon.trophy, title:'Shortlisting top matches', sub:'Picked 3 best fits for you', flair:'pick' },
];

function ThinkingScreen({ onComplete, autoplay = true, loop = false }) {
  const [active, setActive] = React.useState(0); // current in-progress step
  const [done, setDone] = React.useState([]); // completed step indices

  React.useEffect(() => {
    if (!autoplay) return;
    let i = 0;
    let alive = true;
    const advance = () => {
      if (!alive) return;
      setDone(d => [...d, i]);
      i += 1;
      if (i < STEPS.length) {
        setActive(i);
        setTimeout(advance, 1300);
      } else {
        if (loop) {
          setTimeout(() => {
            if (!alive) return;
            setDone([]); setActive(0); i = 0;
            setTimeout(advance, 1300);
          }, 1800);
        } else if (onComplete) {
          setTimeout(onComplete, 700);
        }
      }
    };
    setActive(0);
    const t = setTimeout(advance, 1300);
    return () => { alive = false; clearTimeout(t); };
  }, [autoplay, loop, onComplete]);

  return (
    <ScreenChrome bg="var(--ez-cream)">
      {/* Header */}
      <div style={{
        position:'relative', zIndex:3, padding:'10px 18px 6px',
        display:'flex', alignItems:'center', justifyContent:'space-between',
      }}>
        <div style={{ display:'flex', alignItems:'center', gap:8 }}>
          <div style={{
            width:32, height:32, borderRadius:10, background:'var(--ez-yellow)',
            display:'grid', placeItems:'center',
          }}>
            <EZLogoImg size={20}/>
          </div>
          <div>
            <div style={{ fontSize:12.5, fontWeight:800, letterSpacing:'-0.01em' }}>EZ Agent</div>
            <div style={{ fontSize:10.5, color:'var(--ez-muted)', fontWeight:600,
              display:'inline-flex', alignItems:'center', gap:5,
            }}>
              <span style={{ width:6, height:6, borderRadius:99, background:'#16A34A', boxShadow:'0 0 0 3px rgba(22,163,74,.2)' }}/>
              Thinking live
            </div>
          </div>
        </div>
        <button style={{
          width:32, height:32, borderRadius:999,
          background:'#fff', border:'1px solid var(--ez-border)',
          display:'grid', placeItems:'center', boxShadow:'var(--ez-shadow-sm)',
        }}>{Icon.close('#141414',14)}</button>
      </div>

      {/* User query echo */}
      <div style={{ padding:'10px 16px 0', textAlign:'center' }}>
        <div style={{ fontSize:10.5, fontWeight:700, color:'var(--ez-muted)',
          textTransform:'uppercase', letterSpacing:'0.06em', marginBottom:6 }}>You said</div>
        <div style={{
          background:'#fff', borderRadius:14, padding:'10px 14px',
          border:'1px solid var(--ez-border)', boxShadow:'var(--ez-shadow-sm)',
          fontSize:13.5, fontWeight:600, color:'var(--ez-ink)',
          letterSpacing:'-0.01em', display:'inline-block',
        }}>
          “Mujhe kal subah AC theek karwana hai”
        </div>
      </div>

      {/* Big "Thinking" headline + shimmer */}
      <div style={{ padding:'18px 18px 4px', textAlign:'center' }}>
        <div style={{ display:'inline-flex', alignItems:'center', gap:6, marginBottom:6, justifyContent:'center' }}>
          {Icon.sparkle('var(--ez-yellow-deep)', 14)}
          <span style={{ fontSize:11, fontWeight:800, letterSpacing:'.06em',
            textTransform:'uppercase', color:'var(--ez-yellow-deep)' }}>Reasoning</span>
        </div>
        <h2 style={{
          margin:0, fontFamily:'var(--ez-display)', fontSize:22, lineHeight:1.1,
          fontWeight:600, letterSpacing:'-0.02em',
        }}>
          <span className="ez-shimmer-text">Thinking through your request…</span>
        </h2>
      </div>

      {/* Timeline of steps */}
      <div style={{ position:'relative', padding:'16px 18px 8px', flex:1, minHeight:0, overflow:'auto' }} className="ez-no-scroll">
        {/* vertical rail */}
        <div style={{
          position:'absolute', left:18+18, top:24, bottom:18,
          width:2, background:'var(--ez-border)', borderRadius:2,
        }}/>
        <div style={{
          position:'absolute', left:18+18, top:24,
          width:2, background:'var(--ez-ink)',
          height: `calc(${(done.length / STEPS.length) * 100}% - 0px)`,
          maxHeight:'calc(100% - 24px)',
          transition:'height .8s cubic-bezier(.4,1.2,.4,1)',
          borderRadius:2,
        }}/>

        {STEPS.map((s, i) => {
          const isDone = done.includes(i);
          const isActive = !isDone && i === active;
          const isPending = !isDone && i !== active;
          return (
            <TimelineStep
              key={s.key}
              step={s}
              state={isDone ? 'done' : isActive ? 'active' : 'pending'}
              index={i}
            />
          );
        })}
      </div>

      {/* Status footer */}
      <div style={{
        position:'relative', zIndex:3, padding:'10px 18px 28px',
        background:'linear-gradient(180deg, transparent, var(--ez-cream) 30%)',
      }}>
        <div style={{
          display:'flex', alignItems:'center', justifyContent:'space-between',
          padding:'10px 12px', borderRadius:14, background:'var(--ez-ink)',
          color:'#fff',
        }}>
          <div style={{ display:'flex', alignItems:'center', gap:8 }}>
            <WaveBars/>
            <div>
              <div style={{ fontSize:12, fontWeight:700 }}>Finding the best match…</div>
              <div style={{ fontSize:10, opacity:.6 }}>~ {Math.max(1, STEPS.length - done.length)} sec remaining</div>
            </div>
          </div>
          <div style={{
            fontFamily:'var(--ez-mono)', fontSize:10, fontWeight:700,
            background:'rgba(252,210,74,.18)', color:'var(--ez-yellow)',
            padding:'4px 8px', borderRadius:8, border:'1px solid rgba(252,210,74,.3)',
          }}>{String(done.length).padStart(2,'0')}/{STEPS.length}</div>
        </div>
      </div>
    </ScreenChrome>
  );
}

function WaveBars(){
  return (
    <div style={{ display:'flex', alignItems:'center', gap:2.5, height:18 }}>
      {[0,1,2,3,4].map(i=>(
        <span key={i} style={{
          width:3, height:'100%', borderRadius:2,
          background:'var(--ez-yellow)',
          animation:`ez-wave 0.9s ease-in-out ${i*.1}s infinite`,
          transformOrigin:'center',
        }}/>
      ))}
    </div>
  );
}

function TimelineStep({ step, state, index }) {
  const isDone = state==='done';
  const isActive = state==='active';

  // Done state matches active visually — yellow border + white card + soft glow.
  // Only the icon (→ check) and the status badge (→ DONE) change.
  const filled = isDone || isActive;
  const dotBg = filled ? 'var(--ez-yellow)' : '#fff';
  const dotBorder = filled ? 'var(--ez-yellow)' : 'var(--ez-border)';
  const cardBg = filled ? '#fff' : 'transparent';
  const cardBorder = filled ? '1px solid var(--ez-yellow)' : '1px dashed var(--ez-border)';
  const cardShadow = filled ? '0 8px 24px rgba(252,210,74,.18)' : 'none';

  return (
    <div style={{
      display:'flex', gap:14, marginBottom:14, position:'relative',
      opacity: state==='pending' ? .35 : 1,
      transition:'opacity .4s ease',
      animation: isActive ? 'ez-fade-up .35s ease both' : undefined,
    }}>
      {/* Dot / icon */}
      <div style={{
        width:36, height:36, borderRadius:999, flexShrink:0,
        background:dotBg, border:`2px solid ${dotBorder}`,
        display:'grid', placeItems:'center', position:'relative', zIndex:2,
        boxShadow: filled ? '0 4px 12px rgba(252,210,74,.4)' : 'none',
        animation: isActive ? 'ez-glow-pulse 1.6s ease-in-out infinite' : undefined,
      }}>
        {isDone
          ? Icon.check('#141414', 18)
          : step.icon('#141414', 18)}
        {/* radar pulse only while active */}
        {isActive && (
          <span style={{
            position:'absolute', inset:-2, borderRadius:999,
            border:'2px solid var(--ez-yellow)',
            animation:'ez-pulse 1.6s ease-out infinite',
          }}/>
        )}
      </div>

      {/* Body card */}
      <div style={{
        flex:1, minWidth:0,
        background: cardBg,
        border: cardBorder,
        borderRadius:14, padding:'9px 12px',
        boxShadow: cardShadow,
        position:'relative', overflow:'hidden',
        transition:'all .3s ease',
      }}>
        <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between' }}>
          <div style={{ fontSize:12.5, fontWeight:700, letterSpacing:'-0.01em',
            color: isPending(state) ? 'var(--ez-muted)' : 'var(--ez-ink)' }}>
            {step.title}
          </div>
          {isActive && (
            <span style={{
              fontFamily:'var(--ez-mono)', fontSize:9, fontWeight:700,
              color:'var(--ez-yellow-deep)', display:'inline-flex',
              alignItems:'center', gap:3,
            }}>
              <span style={{ width:4, height:4, borderRadius:99, background:'var(--ez-yellow-deep)',
                animation:'ez-blink 0.9s infinite' }}/>
              RUNNING
            </span>
          )}
          {isDone && (
            <span style={{
              fontFamily:'var(--ez-mono)', fontSize:9, fontWeight:700,
              color:'var(--ez-yellow-deep)', display:'inline-flex',
              alignItems:'center', gap:3,
            }}>
              {Icon.check('var(--ez-yellow-deep)',10)}
              DONE
            </span>
          )}
        </div>
        <div style={{ fontSize:11.5, color:'var(--ez-muted)', marginTop:3, lineHeight:1.35 }}>
          {step.sub}
        </div>

        {/* Step-specific flair (only while running) */}
        {isActive && <StepFlair kind={step.flair}/>}

        {/* Shimmer progress strip only while active */}
        {isActive && (
          <div style={{
            position:'absolute', left:0, bottom:0, height:2, width:'100%',
            background:'linear-gradient(90deg, transparent, var(--ez-yellow) 50%, transparent)',
            backgroundSize:'200% 100%',
            animation:'ez-shimmer 1.4s linear infinite',
          }}/>
        )}
      </div>
    </div>
  );
}

function isPending(state){ return state === 'pending'; }

// Per-step animated flair shown when active
function StepFlair({ kind }){
  if (kind === 'radar') {
    return (
      <div style={{ marginTop:8, height:60, position:'relative',
        borderRadius:10, background:'#FFFDF5', overflow:'hidden',
        border:'1px solid var(--ez-border-soft)',
      }}>
        {/* concentric rings */}
        {[0,1,2].map(i=>(
          <span key={i} style={{
            position:'absolute', left:'50%', top:'50%',
            width:60, height:60, borderRadius:999,
            border:'1.5px solid var(--ez-yellow-deep)',
            transform:'translate(-50%,-50%)',
            opacity:0,
            animation:`ez-radar-ring 2.4s ease-out ${i*.8}s infinite`,
          }}/>
        ))}
        {/* sweep */}
        <div style={{
          position:'absolute', left:'50%', top:'50%',
          width:80, height:80,
          transform:'translate(-50%,-50%)',
          animation:'ez-radar-sweep 2s linear infinite',
        }}>
          <div style={{
            position:'absolute', left:'50%', top:'50%', width:40, height:40,
            background:'conic-gradient(from 0deg, rgba(252,210,74,.5), rgba(252,210,74,0) 60%)',
            transformOrigin:'top left',
          }}/>
        </div>
        {/* provider dots */}
        {[{x:25,y:18},{x:70,y:30},{x:55,y:46},{x:35,y:42},{x:80,y:14}].map((p,i)=>(
          <span key={i} style={{
            position:'absolute', left:`${p.x}%`, top:`${p.y}%`,
            width:6, height:6, borderRadius:99,
            background:'var(--ez-ink)',
            boxShadow:'0 0 0 2px rgba(252,210,74,.4)',
          }}/>
        ))}
        {/* center pin */}
        <span style={{
          position:'absolute', left:'50%', top:'50%', transform:'translate(-50%,-50%)',
          width:10, height:10, borderRadius:99, background:'var(--ez-yellow-deep)',
          border:'2px solid #fff', boxShadow:'0 0 0 2px var(--ez-yellow-deep)',
        }}/>
      </div>
    );
  }
  if (kind === 'parse') {
    const tokens = ['AC Tech', 'G-13', 'Kal subah'];
    return (
      <div style={{ marginTop:8, display:'flex', gap:5, flexWrap:'wrap' }}>
        {tokens.map((t,i)=>(
          <span key={i} style={{
            fontFamily:'var(--ez-mono)', fontSize:10, fontWeight:700,
            padding:'3px 7px', borderRadius:6,
            background:'var(--ez-yellow-glow)', color:'var(--ez-ink)',
            border:'1px solid var(--ez-yellow)',
            animation:`ez-fade-up .4s ease ${i*.15}s both`,
          }}>{t}</span>
        ))}
      </div>
    );
  }
  if (kind === 'stars') {
    return (
      <div style={{ marginTop:8, display:'flex', alignItems:'center', gap:8 }}>
        <div style={{ display:'flex', gap:2 }}>
          {[0,1,2,3,4].map(i=>(
            <span key={i} style={{ animation:`ez-fade-up .4s ease ${i*.1}s both` }}>
              {Icon.star('var(--ez-yellow-deep)', true, 14)}
            </span>
          ))}
        </div>
        <span style={{ fontFamily:'var(--ez-mono)', fontSize:11, fontWeight:700 }}>4.8 avg</span>
        <span style={{ fontSize:10.5, color:'var(--ez-muted)' }}>· 2,140 reviews</span>
      </div>
    );
  }
  if (kind === 'price') {
    return (
      <div style={{ marginTop:8 }}>
        <div style={{
          position:'relative', height:8, borderRadius:99, background:'var(--ez-border-soft)',
        }}>
          <div style={{
            position:'absolute', left:'15%', right:'30%', top:0, bottom:0,
            background:'linear-gradient(90deg, var(--ez-yellow), var(--ez-yellow-deep))',
            borderRadius:99,
          }}/>
          <div style={{
            position:'absolute', left:'40%', top:-2, width:12, height:12,
            borderRadius:99, background:'#fff', border:'2px solid var(--ez-ink)',
          }}/>
        </div>
        <div style={{ display:'flex', justifyContent:'space-between', marginTop:4,
          fontFamily:'var(--ez-mono)', fontSize:9.5, color:'var(--ez-muted)', fontWeight:700 }}>
          <span>₨1,200</span><span style={{ color:'var(--ez-ink)'}}>median ₨1,850</span><span>₨3,800</span>
        </div>
      </div>
    );
  }
  if (kind === 'cal') {
    return (
      <div style={{ marginTop:8, display:'flex', gap:4 }}>
        {['9:00','10:30','11:00','12:00'].map((t,i)=>(
          <span key={i} style={{
            flex:1, textAlign:'center', fontFamily:'var(--ez-mono)', fontSize:10, fontWeight:700,
            padding:'5px 0', borderRadius:7,
            background: i===1 ? 'var(--ez-ink)' : '#FFFDF5',
            color: i===1 ? 'var(--ez-yellow)' : 'var(--ez-ink)',
            border:'1px solid var(--ez-border-soft)',
            animation:`ez-fade-up .4s ease ${i*.08}s both`,
          }}>{t}</span>
        ))}
      </div>
    );
  }
  if (kind === 'pick') {
    return (
      <div style={{ marginTop:8, display:'flex', gap:5 }}>
        {[1,2,3].map(n=>(
          <div key={n} style={{
            flex:1, height:34, borderRadius:8,
            background: n===1 ? 'linear-gradient(135deg, var(--ez-yellow), var(--ez-yellow-deep))' : '#FFFDF5',
            border:'1px solid var(--ez-border-soft)',
            display:'flex', alignItems:'center', justifyContent:'center', gap:4,
            fontFamily:'var(--ez-mono)', fontSize:11, fontWeight:800,
            color: n===1 ? 'var(--ez-ink)' : 'var(--ez-muted)',
            animation:`ez-fade-up .4s ease ${n*.1}s both`,
          }}>
            {n===1 && Icon.trophy('#141414',12)}
            #{n}
          </div>
        ))}
      </div>
    );
  }
  return null;
}

Object.assign(window, { ThinkingScreen, WaveBars });
