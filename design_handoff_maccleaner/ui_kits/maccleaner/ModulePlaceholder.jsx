// =========================================================
// Placeholder rendered for modules we didn't fully recreate.
// =========================================================
function ModulePlaceholder({ moduleId }) {
  const mod = window.MODULE_BY_ID[moduleId];
  const sec = window.SECTION_BY_ID[mod.section];
  return (
    <div className="module">
      <ModuleHeader icon={mod.icon} title={mod.title} accent={sec.accent}
        subtitle={`${sec.label.slice(0,1)}${sec.label.slice(1).toLowerCase()} module`} />
      <div className="placeholder">
        <div>
          <div className="placeholder-icon" style={{
            background: `linear-gradient(135deg, ${sec.accent}30, ${sec.accent}10)`,
            border: `0.5px solid ${sec.accent}40`,
            color: sec.accent
          }}>
            <Icon name={mod.icon} size={48} color={sec.accent} />
          </div>
          <div className="placeholder-title">{mod.title}</div>
          <div className="placeholder-body">
            This kit ships pixel-real Smart Care, System Junk, Memory and Sensors.
            Other modules show this placeholder — point at one in the codebase and it gets
            recreated the same way.
          </div>
          <div style={{ marginTop: 16 }}>
            <Button kind="primary">Open module</Button>
          </div>
        </div>
      </div>
    </div>
  );
}

window.ModulePlaceholder = ModulePlaceholder;
