// =========================================================
// Sensors — temperature + fan + power tile grid.
// =========================================================
function Sensors() {
  const data = window.SENSORS;
  const groups = useMemo(() => {
    const m = {};
    for (const s of data) (m[s.group] ||= []).push(s);
    return m;
  }, [data]);

  return (
    <div className="module">
      <ModuleHeader
        icon="thermometer" accent="#64D2FF"
        title="Sensors" subtitle="SMC + IOKit feeds"
        trailing={<>
          <Chip>°C</Chip>
          <Chip active>°F</Chip>
          <Button icon="download">Export</Button>
        </>}
      />
      <div style={{ flex: 1, overflowY: "auto", padding: "12px 16px 18px" }}>
        {Object.entries(groups).map(([g, items]) => (
          <div key={g} style={{ marginBottom: 18 }}>
            <Eyebrow count={items.length} style={{ marginBottom: 8 }}>{g.toUpperCase()}</Eyebrow>
            <div style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fill, minmax(180px, 1fr))",
              gap: 10,
            }}>
              {items.map(s => <SensorTile key={s.id} s={s} />)}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function SensorTile({ s }) {
  // synthesize a 24-sample trace varying around the current value
  const trace = useMemo(() => {
    const arr = [];
    for (let i = 0; i < 24; i++) {
      arr.push(s.value * (0.85 + Math.random() * 0.30));
    }
    arr.push(s.value);
    return arr;
  }, [s.id, s.value]);
  const color = s.tint === "warn" ? "#FF9F0A" : s.tint === "ok" ? "#30D158" : "#64D2FF";
  return (
    <div className="tile" style={{ padding: 12 }}>
      <div style={{ display: "flex", alignItems: "baseline", gap: 6 }}>
        <span className="label" style={{ flex: 1 }}>{s.label}</span>
        <span style={{ font: "9px var(--font-sans)", color: "var(--fg-quaternary)", textTransform: "uppercase", letterSpacing: "0.04em" }}>{s.unit}</span>
      </div>
      <div style={{
        font: "600 24px var(--font-mono)",
        fontVariantNumeric: "tabular-nums",
        color, marginTop: 4
      }}>
        {typeof s.value === "number" ? s.value.toFixed(s.value < 100 && !Number.isInteger(s.value) ? 1 : 0) : s.value}
      </div>
      <div style={{ height: 24, marginTop: 4 }}>
        <Sparkline values={trace} color={color} height={24} />
      </div>
    </div>
  );
}

window.Sensors = Sensors;
