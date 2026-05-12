// =========================================================
// Memory — RAM breakdown + top processes.
// =========================================================
function Memory() {
  const m = window.MEMORY;
  const fmt = (g) => g.toFixed(1) + " GB";
  const procs = [...window.PROCESSES].sort((a, b) => b.mem - a.mem);

  // synth a sparkline
  const trace = useMemo(() => {
    const arr = [];
    let v = 55;
    for (let i = 0; i < 48; i++) { v += (Math.random() - 0.5) * 8; v = Math.max(20, Math.min(85, v)); arr.push(v); }
    return arr;
  }, []);

  return (
    <div className="module">
      <ModuleHeader
        icon="memory-stick" accent="#64D2FF"
        title="Memory" subtitle="32 GB unified · live"
        trailing={<>
          <Button icon="pause">Pause</Button>
          <Button kind="primary" icon="zap">Free RAM</Button>
        </>}
      />

      <div style={{ flex: 1, overflowY: "auto", padding: "12px 16px 16px" }}>
        <div className="card" style={{ padding: 16 }}>
          <div style={{ display: "flex", alignItems: "baseline", gap: 12 }}>
            <Eyebrow>Pressure</Eyebrow>
            <div style={{ flex: 1 }} />
            <span style={{ font: "var(--type-body-sm)", color: "var(--color-warning)" }}>
              Yellow — apps may swap to disk
            </span>
          </div>
          <div style={{ height: 60, marginTop: 4 }}>
            <Sparkline values={trace} color="#FF9F0A" height={60} />
          </div>
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(5, 1fr)", gap: 12, marginTop: 12 }}>
          <Tile label="App memory"  value={fmt(m.appGB)}        swatch="#5AB0FF" />
          <Tile label="Wired"       value={fmt(m.wiredGB)}      swatch="#FF9F0A" />
          <Tile label="Compressed"  value={fmt(m.compressedGB)} swatch="#FF453A" />
          <Tile label="Cached files" value={fmt(m.cachedGB)}    swatch="#30D158" />
          <Tile label="Free"        value={fmt(m.freeGB)}       swatch="#8E8DEF" />
        </div>

        <div style={{ marginTop: 12 }}>
          <Eyebrow>Allocation · {m.totalGB} GB total</Eyebrow>
          <div className="bar" style={{ marginTop: 6, height: 22 }}>
            {bar(m.appGB,        m.totalGB, "#5AB0FF", "App")}
            {bar(m.wiredGB,      m.totalGB, "#FF9F0A", "Wired")}
            {bar(m.compressedGB, m.totalGB, "#FF453A", "Compressed")}
            {bar(m.cachedGB,     m.totalGB, "#30D158", "Cached")}
            {bar(m.freeGB,       m.totalGB, "rgba(255,255,255,0.10)", "Free")}
          </div>
        </div>

        <div style={{ marginTop: 18, display: "flex", alignItems: "center", gap: 8 }}>
          <Eyebrow count={procs.length}>TOP PROCESSES</Eyebrow>
          <div style={{ flex: 1 }} />
          <Chip active>By memory</Chip>
          <Chip>By CPU</Chip>
        </div>

        <div className="card" style={{ marginTop: 8, padding: 0, overflow: "hidden" }}>
          <div style={{
            display: "grid",
            gridTemplateColumns: "20px 1fr 80px 80px 100px 28px",
            padding: "8px 12px",
            font: "var(--type-eyebrow)",
            color: "var(--fg-quaternary)",
            borderBottom: "0.5px solid var(--border-hairline)"
          }}>
            <span></span>
            <span>PROCESS</span>
            <span style={{ textAlign: "right" }}>PID</span>
            <span style={{ textAlign: "right" }}>CPU</span>
            <span style={{ textAlign: "right" }}>MEMORY</span>
            <span></span>
          </div>
          {procs.map(p => (
            <div key={p.pid} style={{
              display: "grid",
              gridTemplateColumns: "20px 1fr 80px 80px 100px 28px",
              alignItems: "center",
              padding: "8px 12px",
              borderBottom: "0.5px solid var(--border-hairline)",
            }}>
              <Icon name="cpu" size={14} color="#64D2FF" />
              <span style={{ font: "var(--type-body-md)" }}>{p.name}</span>
              <span className="num-md" style={{ textAlign: "right", color: "var(--fg-tertiary)" }}>{p.pid}</span>
              <span className="num-md" style={{ textAlign: "right", color: p.cpu > 60 ? "#FF9F0A" : "var(--fg-secondary)" }}>{p.cpu}%</span>
              <span className="num-md" style={{ textAlign: "right" }}>{window.helpers.fmtBytesRound(p.mem)}</span>
              <Icon name="x" size={14} color="var(--fg-quaternary)" />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function Tile({ label, value, swatch }) {
  return (
    <div className="tile">
      <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
        <span style={{ width: 8, height: 8, borderRadius: 2, background: swatch }} />
        <span className="label">{label}</span>
      </div>
      <div className="value" style={{ marginTop: 4 }}>{value}</div>
    </div>
  );
}

window.Memory = Memory;
