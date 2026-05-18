// screen1b-composer.jsx — Conversational input screen (Claude/GPT-style composer)

function ComposerScreen({ onSend, onBack }) {
  const [text, setText] = React.useState('');
  const [attachments, setAttachments] = React.useState([]); // [{name, color}]
  const [listening, setListening] = React.useState(false);
  const inputRef = React.useRef(null);

  const submit = () => {
    if (!text.trim() && attachments.length === 0) return;
    if (onSend) onSend({ text: text.trim() || 'Mujhe kal subah AC theek karwana hai', attachments });
  };

  const onKey = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {e.preventDefault();submit();}
  };

  // Auto-grow textarea
  React.useEffect(() => {
    const el = inputRef.current;
    if (!el) return;
    el.style.height = 'auto';
    el.style.height = Math.min(110, el.scrollHeight) + 'px';
  }, [text]);

  const suggestions = [
  { i: Icon.ac, l: 'AC stopped cooling' },
  { i: Icon.wrench, l: 'Leaking tap fix' },
  { i: Icon.bolt, l: 'Light fitting' },
  { i: Icon.broom, l: 'Deep house clean' }];


  return (
    <ScreenChrome bg="var(--ez-cream)">
      {/* Header */}
      <div style={{
        padding: '8px 16px 4px', display: 'flex', alignItems: 'center',
        justifyContent: 'space-between', position: 'relative', zIndex: 3
      }}>
        <button onClick={onBack} style={{
          width: 36, height: 36, borderRadius: 999, background: '#fff',
          border: '1px solid var(--ez-border)',
          display: 'grid', placeItems: 'center', boxShadow: 'var(--ez-shadow-sm)'
        }}>{Icon.back('#141414', 16)}</button>
        <button style={{
          width: 36, height: 36, borderRadius: 999, background: '#fff',
          border: '1px solid var(--ez-border)',
          display: 'grid', placeItems: 'center', boxShadow: 'var(--ez-shadow-sm)'
        }}>{Icon.close('#141414', 14)}</button>
      </div>

      {/* Center visual + welcome — flex grows to fill space above input */}
      <div style={{
        flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center',
        padding: '12px 24px 8px', position: 'relative', textAlign: 'center'
      }}>
        {/* Floating mark with halo */}
        <div style={{
          position: 'relative', width: 108, height: 108,
          display: 'grid', placeItems: 'center', marginBottom: 14,
          animation: 'ez-fade-up .5s ease both'
        }}>
          {/* halo */}
          <div style={{
            position: 'absolute', inset: 0, borderRadius: 999,
            background: 'radial-gradient(circle at center, rgba(252,210,74,.55), transparent 65%)'
          }} />
          {/* concentric soft rings */}
          {[0, 1].map((i) =>
          <span key={i} style={{
            position: 'absolute', inset: i ? 8 : -2, borderRadius: 999,
            border: '1px solid var(--ez-yellow)', opacity: .5,
            animation: `ez-pulse 2.6s ease-out ${i * .6}s infinite`
          }} />
          )}
          {/* center disk with logo */}
          <div style={{
            position: 'relative', width: 72, height: 72, borderRadius: 24,
            background: 'linear-gradient(135deg, #FCD24A, #FFE988)',
            display: 'grid', placeItems: 'center',
            boxShadow: '0 12px 28px rgba(232,182,23,.35), inset 0 -3px 0 rgba(20,20,20,.06)',
            border: '1px solid rgba(20,20,20,.08)'
          }}>
            <EZLogoImg size={38} />
          </div>
          {/* tiny sparkle dots — symmetric around the 108×108 hero box */}
          {[{ x: -4, y: 14 }, { x: 108, y: 14 }, { x: -4, y: 90 }, { x: 108, y: 90 }].map((p, i) =>
          <span key={i} style={{
            position: 'absolute', left: p.x, top: p.y,
            width: 6, height: 6, borderRadius: 99,
            background: i % 2 ? 'var(--ez-ink)' : 'var(--ez-yellow-deep)',
            animation: `ez-blink ${1.4 + i * .2}s ease ${i * .15}s infinite`
          }} />
          )}
        </div>

        <div style={{
          fontSize: 10.5, fontWeight: 800, color: 'var(--ez-yellow-deep)',
          textTransform: 'uppercase', letterSpacing: '.1em', marginBottom: 8,
          display: 'inline-flex', alignItems: 'center', gap: 4, justifyContent: 'center'
        }}>
          {Icon.sparkle('var(--ez-yellow-deep)', 10)} EZ Agent
        </div>
        <h2 style={{
          margin: 0, fontFamily: 'var(--ez-display)', fontSize: 24, lineHeight: 1.1,
          fontWeight: 600, letterSpacing: '-0.02em', color: 'var(--ez-ink)',
          animation: 'ez-fade-up .5s ease .1s both'
        }}>
          How can we assist<br />you today?
        </h2>
        <p style={{
          margin: '10px 0 0', fontSize: 12.5, color: 'var(--ez-ink-soft)',
          lineHeight: 1.45, maxWidth: 240, fontWeight: 500,
          animation: 'ez-fade-up .5s ease .2s both'
        }}>
          Type, speak, or share a photo. Urdu, English, Roman — sab chalega.
        </p>

        {/* Suggestion chips */}
        <div style={{
          display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6, marginTop: 18,
          width: '100%', maxWidth: 280,
          animation: 'ez-fade-up .5s ease .3s both'
        }}>
          {suggestions.map((s, i) =>
          <button key={i} onClick={() => setText(s.l)} style={{
            display: 'inline-flex', alignItems: 'center', gap: 6, justifyContent: 'center',
            padding: '8px 10px', borderRadius: 12,
            background: '#fff', border: '1px solid var(--ez-border)',
            fontSize: 11.5, fontWeight: 700, color: 'var(--ez-ink)',
            letterSpacing: '-0.01em',
            boxShadow: 'var(--ez-shadow-sm)', cursor: 'pointer', textAlign: "left"
          }}>
              <span style={{
              width: 22, height: 22, borderRadius: 6, background: 'var(--ez-yellow-glow)',
              display: 'grid', placeItems: 'center', flexShrink: 0
            }}>{s.i('#141414', 13)}</span>
              <span style={{ minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.l}</span>
            </button>
          )}
        </div>
      </div>

      {/* Voice listening overlay strip (appears when listening) */}
      {listening &&
      <div style={{
        margin: '0 16px 8px', padding: '8px 12px', borderRadius: 12,
        background: 'var(--ez-ink)', color: '#fff',
        display: 'flex', alignItems: 'center', gap: 10,
        animation: 'ez-fade-up .25s ease both'
      }}>
          <WaveBars />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 11.5, fontWeight: 700 }}>Listening… speak now</div>
            <div style={{ fontSize: 10, opacity: .6 }}>Urdu, English, Roman — sab samjhta hai</div>
          </div>
          <button onClick={() => setListening(false)} style={{
          padding: '4px 8px', borderRadius: 999,
          background: 'rgba(255,255,255,.12)', color: '#fff',
          fontSize: 10, fontWeight: 800
        }}>STOP</button>
        </div>
      }

      {/* Composer — pinned to bottom */}
      <div style={{
        position: 'relative', zIndex: 3, padding: '10px 12px 24px'
      }}>
        <div style={{
          background: '#fff', borderRadius: 22,
          border: '1px solid var(--ez-border)',
          boxShadow: '0 2px 4px rgba(20,20,20,.04), 0 16px 36px rgba(20,20,20,.08)',
          padding: attachments.length ? '8px 10px 8px' : '6px 8px 6px'
        }}>
          {/* Attachment chips */}
          {attachments.length > 0 &&
          <div style={{ display: 'flex', gap: 6, padding: '2px 4px 6px', flexWrap: 'wrap' }}>
              {attachments.map((a, i) =>
            <div key={i} style={{
              display: 'inline-flex', alignItems: 'center', gap: 6,
              padding: '4px 8px 4px 4px', borderRadius: 10,
              background: 'var(--ez-yellow-glow)', border: '1px solid var(--ez-yellow)'
            }}>
                  <span style={{
                width: 22, height: 22, borderRadius: 6,
                background: a.color, border: '1px solid rgba(20,20,20,.08)'
              }} />
                  <span style={{ fontSize: 10.5, fontWeight: 700 }}>{a.name}</span>
                  <button onClick={() => setAttachments((arr) => arr.filter((_, x) => x !== i))}
              style={{ display: 'grid', placeItems: 'center', padding: 2 }}>
                    {Icon.close('#141414', 10)}
                  </button>
                </div>
            )}
            </div>
          }

          {/* Textarea row */}
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, padding: '4px 4px' }}>
            <textarea
              ref={inputRef}
              value={text}
              onChange={(e) => setText(e.target.value)}
              onKeyDown={onKey}
              placeholder="Apko konsi service chahiyay?"
              rows={1}
              style={{
                flex: 1, minWidth: 0, resize: 'none', border: 0, outline: 'none',
                padding: '10px 6px 6px 10px', background: 'transparent',
                fontFamily: 'var(--ez-sans)', fontSize: 14, color: 'var(--ez-ink)',
                letterSpacing: '-0.01em', lineHeight: 1.35, maxHeight: 110
              }} />
            
          </div>

          {/* Tool row */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6, padding: '2px 6px 4px'
          }}>
            <ToolBtn onClick={() => setAttachments((a) => [...a, {
              name: 'Photo.jpg',
              color: ['#FCD24A', '#FFE988', '#F4EFE2'][a.length % 3]
            }])} title="Attach photo">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <path d="M21 12.5L13 20a5 5 0 0 1-7-7L14 5a3.5 3.5 0 0 1 5 5L11 18a2 2 0 0 1-3-3l7-7"
                stroke="#141414" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </ToolBtn>
            <ToolBtn title="Camera">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <path d="M4 8h3l2-3h6l2 3h3a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2Z"
                stroke="#141414" strokeWidth="1.8" strokeLinejoin="round" />
                <circle cx="12" cy="13" r="3.5" stroke="#141414" strokeWidth="1.8" />
              </svg>
            </ToolBtn>
            <ToolBtn title="Location">
              {Icon.pin('#141414', 16)}
            </ToolBtn>

            <div style={{ flex: 1 }} />

            {/* Voice button */}
            <button onClick={() => setListening((l) => !l)} style={{
              width: 36, height: 36, borderRadius: 999, display: 'grid', placeItems: 'center',
              background: listening ? 'var(--ez-ink)' : '#fff',
              border: `1px solid ${listening ? 'var(--ez-ink)' : 'var(--ez-border)'}`,
              boxShadow: listening ? '0 0 0 4px rgba(252,210,74,.35)' : 'none',
              transition: 'all .2s ease', cursor: 'pointer'
            }}>
              {Icon.mic(listening ? '#FCD24A' : '#141414', 18)}
            </button>

            {/* Send */}
            <button onClick={submit} disabled={!text.trim() && attachments.length === 0} style={{
              width: 36, height: 36, borderRadius: 999, display: 'grid', placeItems: 'center',
              background: text.trim() || attachments.length ? 'var(--ez-ink)' : '#E8E2D2',
              boxShadow: text.trim() || attachments.length ? '0 4px 12px rgba(20,20,20,.18)' : 'none',
              cursor: 'pointer', transition: 'all .2s ease'
            }}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <path d="M5 12h14M13 6l6 6-6 6"
                stroke={text.trim() || attachments.length ? '#FCD24A' : '#B5AE9E'}
                strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </button>
          </div>
        </div>
        <div style={{
          marginTop: 7, textAlign: 'center', fontSize: 10, color: 'var(--ez-muted)', fontWeight: 600
        }}>
          EZ may suggest local providers. Confirm before booking.
        </div>
      </div>
    </ScreenChrome>);

}

function ToolBtn({ children, onClick, title }) {
  return (
    <button onClick={onClick} title={title} style={{
      width: 32, height: 32, borderRadius: 999, display: 'grid', placeItems: 'center',
      background: 'transparent', border: '1px solid transparent',
      transition: 'all .15s ease', cursor: 'pointer'
    }}
    onMouseEnter={(e) => {e.currentTarget.style.background = 'var(--ez-cream-2)';e.currentTarget.style.borderColor = 'var(--ez-border)';}}
    onMouseLeave={(e) => {e.currentTarget.style.background = 'transparent';e.currentTarget.style.borderColor = 'transparent';}}>
      {children}
    </button>);

}

Object.assign(window, { ComposerScreen });