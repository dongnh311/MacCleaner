// =========================================================
// Menu-bar status strip — floats over the window like the real
// macOS menu extra dropdown. Not part of the window content.
// =========================================================
function Menubar() {
  return (
    <div className="menubar-pop">
      <span className="sparkle"><Icon name="sparkles" size={12} /></span>
      <span><span className="lbl">CPU</span> 41%</span>
      <span style={{ color: "#FF9F0A" }}><span className="lbl" style={{ color: "var(--fg-tertiary)" }}>MEM</span> 78%</span>
      <span><span className="lbl">NET ↓</span> 14.2 MB/s</span>
      <span><span className="lbl">°C</span> 72</span>
      <Icon name="chevron-down" size={10} color="var(--fg-tertiary)" />
    </div>
  );
}

window.Menubar = Menubar;
