// =========================================================
// Three-column NavigationSplitView sidebar.
// =========================================================
function Sidebar({ active, onSelect }) {
  return (
    <div className="sidebar">
      <div className="sidebar-scroll">
        {window.SECTIONS.map(section => {
          const modules = window.MODULES.filter(m => m.section === section.id);
          return (
            <div key={section.id}>
              <div className="sb-section-label">{section.label}</div>
              {modules.map(m => (
                <div
                  key={m.id}
                  className={"sb-item" + (active === m.id ? " active" : "")}
                  onClick={() => onSelect(m.id)}
                >
                  <Icon name={m.icon} size={16} color={section.accent} />
                  <span>{m.title}</span>
                  {m.shortcut && <span className="kbd">{m.shortcut}</span>}
                </div>
              ))}
            </div>
          );
        })}
      </div>
      <div className="sidebar-footer">
        <Icon name="hard-drive" size={12} />
        <span>184.2 GB free</span>
        <div style={{ flex: 1 }} />
        <Icon name="settings" size={12} />
      </div>
    </div>
  );
}

window.Sidebar = Sidebar;
