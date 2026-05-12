// =========================================================
// macOS window chrome + unified backdrop. Pure presentation —
// content goes in as children.
// =========================================================
function Window({ title = "MacCleaner", accentTint, children }) {
  return (
    <div className="window" style={accentTint ? {
      "--module-tint": `linear-gradient(180deg, ${accentTint}14, transparent 25%)`
    } : null}>
      <div className="titlebar">
        <div className="tl red" />
        <div className="tl yellow" />
        <div className="tl green" />
        <div className="title">{title}</div>
        <div className="toolbar-right">
          <Icon name="search" size={14} />
          <Icon name="panel-right" size={14} />
        </div>
      </div>
      {children}
    </div>
  );
}

window.Window = Window;
