// screen3-results.jsx — Top 3 Provider Results

function ResultsScreen({ onBook }) {
  return (
    <ScreenChrome bg="var(--ez-cream)">
      {/* Header */}
      <div style={{ padding:'8px 16px 4px',
        display:'flex', alignItems:'center', justifyContent:'space-between',
      }}>
        <button style={{
          width:36, height:36, borderRadius:999, background:'#fff',
          border:'1px solid var(--ez-border)',
          display:'grid', placeItems:'center', boxShadow:'var(--ez-shadow-sm)',
        }}>{Icon.back('#141414',16)}</button>
        <div style={{ textAlign:'center' }}>
          <div style={{ fontSize:13, fontWeight:800, letterSpacing:'-0.01em' }}>Top 3 matches</div>
          <div style={{ fontSize:10.5, color:'var(--ez-muted)', fontWeight:600 }}>AC Repair · G-13 · Tomorrow AM</div>
        </div>
        <button style={{
          width:36, height:36, borderRadius:999, background:'#fff',
          border:'1px solid var(--ez-border)',
          display:'grid', placeItems:'center', boxShadow:'var(--ez-shadow-sm)',
          fontSize:11, fontWeight:800,
        }}>↻</button>
      </div>

      {/* Insight bar */}
      <div style={{ padding:'8px 16px 12px' }}>
        <div style={{
          display:'flex', alignItems:'center', gap:8,
          padding:'8px 12px', borderRadius:12,
          background:'var(--ez-yellow-glow)',
          border:'1px solid var(--ez-yellow)',
        }}>
          <div style={{
            width:22, height:22, borderRadius:6,
            background:'var(--ez-ink)', display:'grid', placeItems:'center',
          }}>{Icon.sparkle('var(--ez-yellow)', 12)}</div>
          <div style={{ fontSize:11.5, lineHeight:1.3, fontWeight:600, color:'var(--ez-ink)' }}>
            Picked 3 of 24 pros based on rating, distance &amp; price.
          </div>
        </div>
      </div>

      {/* Cards */}
      <div className="ez-no-scroll" style={{ padding:'2px 16px 20px', overflow:'auto', flex:1 }}>
        <ProviderCard
          rank={1}
          name="Asad Mehmood"
          shop="CoolFix HVAC Pros"
          rating={4.9}
          reviews={312}
          distance="1.2 km"
          price="₨1,500–2,500"
          slot="Tomorrow, 9–12 AM"
          reasons={['Closest','Highest Rated','Best Price']}
          accent="#FCD24A"
          onBook={onBook}
          aiPick
        />
        <ProviderCard
          rank={2}
          name="Bilal Khan"
          shop="QuickCool Service"
          rating={4.7}
          reviews={184}
          distance="2.1 km"
          price="₨1,800–2,800"
          slot="Tomorrow, 11 AM"
          reasons={['Highly Rated','Verified']}
          accent="#F4EFE2"
        />
        <ProviderCard
          rank={3}
          name="Umar Tariq"
          shop="ChillMaster ACs"
          rating={4.6}
          reviews={97}
          distance="3.4 km"
          price="₨1,400–2,400"
          slot="Tomorrow, 12 PM"
          reasons={['Lowest Price']}
          accent="#FFFAE0"
        />
      </div>
    </ScreenChrome>
  );
}

function ProviderCard({ rank, name, shop, rating, reviews, distance, price, slot, reasons, accent, aiPick=false, onBook }) {
  return (
    <div style={{
      position:'relative', marginBottom: aiPick ? 16 : 12,
      borderRadius: 20,
      background:'#fff',
      border: aiPick ? '1.5px solid var(--ez-yellow)' : '1px solid var(--ez-border)',
      boxShadow: aiPick
        ? '0 0 0 4px rgba(252,210,74,.18), 0 18px 40px rgba(232,182,23,.18), 0 4px 12px rgba(20,20,20,.06)'
        : 'var(--ez-shadow-sm)',
      padding: aiPick ? '14px 14px 14px' : '12px 12px 12px',
      overflow:'hidden',
    }}>
      {/* AI Pick ribbon */}
      {aiPick && (
        <div style={{
          position:'absolute', top:0, right:0,
          padding:'4px 10px 4px 12px',
          background:'var(--ez-ink)', color:'var(--ez-yellow)',
          fontSize:9.5, fontWeight:800, letterSpacing:'0.06em',
          borderBottomLeftRadius:12,
          display:'inline-flex', alignItems:'center', gap:5,
        }}>
          {Icon.sparkle('var(--ez-yellow)',10)} AI PICK
        </div>
      )}

      <div style={{ display:'flex', gap:12 }}>
        {/* Avatar */}
        <div style={{
          width: aiPick ? 62 : 52, height: aiPick ? 62 : 52,
          borderRadius:16, flexShrink:0,
          background: `linear-gradient(135deg, ${accent}, #FFE988)`,
          position:'relative', overflow:'hidden',
          border:'1px solid var(--ez-border-soft)',
          display:'grid', placeItems:'center',
        }}>
          {/* striped placeholder texture */}
          <div style={{
            position:'absolute', inset:0,
            background:'repeating-linear-gradient(45deg, rgba(20,20,20,0) 0 6px, rgba(20,20,20,.04) 6px 7px)',
          }}/>
          <span style={{
            position:'relative', fontFamily:'var(--ez-display)', fontWeight:700,
            fontSize: aiPick ? 24 : 20, color:'var(--ez-ink)',
          }}>{name.split(' ').map(s=>s[0]).slice(0,2).join('')}</span>
          {aiPick && (
            <span style={{
              position:'absolute', bottom:-4, right:-4,
              width:22, height:22, borderRadius:99,
              background:'var(--ez-ink)', display:'grid', placeItems:'center',
              border:'2px solid #fff',
            }}>{Icon.trophy('var(--ez-yellow)',12)}</span>
          )}
        </div>

        {/* Name + meta */}
        <div style={{ flex:1, minWidth:0 }}>
          <div style={{ display:'flex', alignItems:'center', gap:5 }}>
            <span style={{ fontSize: aiPick?15:14, fontWeight:800, letterSpacing:'-0.01em' }}>{name}</span>
            {Icon.shield('var(--ez-info)', 13)}
          </div>
          <div style={{ fontSize:11.5, color:'var(--ez-muted)', fontWeight:600, marginTop:1 }}>
            {shop} · {distance}
          </div>
          <div style={{ display:'flex', alignItems:'center', gap:5, marginTop:5 }}>
            {Icon.star('var(--ez-yellow-deep)', true, 12)}
            <span style={{ fontSize:11.5, fontWeight:800 }}>{rating}</span>
            <span style={{ fontSize:11, color:'var(--ez-muted)'}}>({reviews})</span>
            <span style={{ width:3, height:3, borderRadius:99, background:'var(--ez-muted-2)' }}/>
            <span style={{ fontSize:11, color:'var(--ez-ink-soft)', fontWeight:700 }}>{price}</span>
          </div>
        </div>
      </div>

      {/* Availability tag */}
      <div style={{
        marginTop:10, display:'inline-flex', alignItems:'center', gap:5,
        padding:'4px 9px', borderRadius:999,
        background:'var(--ez-success-soft)',
        border:'1px solid #BBF7D0',
      }}>
        <span style={{ width:6, height:6, borderRadius:99, background:'var(--ez-success)' }}/>
        <span style={{ fontSize:10.5, fontWeight:700, color:'#166534' }}>Available {slot}</span>
      </div>

      {/* Reasoning pills */}
      <div style={{
        marginTop:10, display:'flex', gap:5, flexWrap:'wrap',
        padding:'8px 10px', borderRadius:12,
        background: aiPick ? 'var(--ez-yellow-glow)' : 'var(--ez-cream)',
        border:`1px dashed ${aiPick?'var(--ez-yellow)':'var(--ez-border)'}`,
      }}>
        <span style={{
          fontSize:9.5, fontWeight:800, color:'var(--ez-ink-soft)',
          textTransform:'uppercase', letterSpacing:'.06em',
          display:'inline-flex', alignItems:'center', gap:3,
        }}>
          {Icon.sparkle('var(--ez-yellow-deep)',9)} Why this one
        </span>
        {reasons.map((r,i)=>(
          <span key={i} style={{
            fontSize:10, fontWeight:700, padding:'2px 7px', borderRadius:999,
            background:'#fff', border:'1px solid var(--ez-border-soft)',
            color:'var(--ez-ink)',
          }}>{r}</span>
        ))}
      </div>

      {/* CTAs */}
      <div style={{ marginTop:12, display:'flex', gap:8 }}>
        <PillBtn full variant={aiPick?'primary':'soft'} onClick={onBook} style={{ padding:'11px 14px', fontSize:13.5, flex:2 }}>
          Book Now
        </PillBtn>
        <PillBtn variant="ghost" style={{ padding:'11px 14px', fontSize:13, flex:1 }}>
          Profile
        </PillBtn>
      </div>
    </div>
  );
}

Object.assign(window, { ResultsScreen, ProviderCard });
