// =========================================================
// System Junk — HSplit (category list | item detail), with hero,
// confirm-bar, and sticky action-bar. Mirrors CleanupModuleView.
// =========================================================
function SystemJunk() {
  const items = window.JUNK_ITEMS;
  const cats = window.JUNK_CATEGORIES;
  const [activeCat, setActiveCat] = useState("Xcode");
  const [selected, setSelected] = useState(() => new Set(
    items.filter(i => i.safety === "safe").map(i => i.path)
  ));
  const [confirm, setConfirm] = useState(false);
  const [sort, setSort] = useState("Size ↓");

  const byCat = useMemo(() => {
    const m = {};
    for (const i of items) (m[i.cat] ||= []).push(i);
    return m;
  }, [items]);

  const totalBytes = items.reduce((a, i) => a + i.size, 0);
  const selSize = items.filter(i => selected.has(i.path)).reduce((a, i) => a + i.size, 0);
  const fmt = window.helpers.fmtBytes;

  function toggle(path) {
    const next = new Set(selected);
    next.has(path) ? next.delete(path) : next.add(path);
    setSelected(next);
  }
  function toggleCat(cat) {
    const paths = byCat[cat].map(i => i.path);
    const allOn = paths.every(p => selected.has(p));
    const next = new Set(selected);
    paths.forEach(p => allOn ? next.delete(p) : next.add(p));
    setSelected(next);
  }
  function selectionState(cat) {
    const paths = byCat[cat].map(i => i.path);
    const c = paths.filter(p => selected.has(p)).length;
    if (c === 0) return { value: false };
    if (c === paths.length) return { value: true };
    return { mixed: true };
  }

  const detailItems = byCat[activeCat] || [];
  const detailSorted = useMemo(() => {
    const a = [...detailItems];
    if (sort.startsWith("Size")) a.sort((x, y) => y.size - x.size);
    else if (sort === "Name") a.sort((x, y) => x.name.localeCompare(y.name));
    return a;
  }, [detailItems, sort]);
  const subgroups = useMemo(() => {
    const g = {};
    for (const i of detailSorted) (g[i.group] ||= []).push(i);
    return Object.entries(g).map(([k, v]) => ({
      title: k, items: v, total: v.reduce((a, i) => a + i.size, 0),
    }));
  }, [detailSorted]);

  return (
    <div className="module">
      <ModuleHeader
        icon="trash-2" accent="#FF9F0A"
        title="System Junk" subtitle="Caches, logs, dev-tool junk"
        trailing={<Button icon="refresh-cw">Rescan</Button>}
      />

      {/* hero zone — one-line, dense */}
      <div style={{ display: "flex", alignItems: "baseline", gap: 12, padding: "10px 16px" }}>
        <span className="num-lg" style={{ font: "600 22px var(--font-mono)", fontVariantNumeric: "tabular-nums" }}>
          {fmt(totalBytes)}
        </span>
        <span style={{ font: "var(--type-body-md)", color: "var(--fg-secondary)" }}>
          {items.length} items
        </span>
        <div style={{ flex: 1 }} />
        <span style={{ font: "var(--type-body-sm)", color: "var(--color-success)" }}>
          Restored 15 items from previous scan (12s ago)
        </span>
      </div>
      <div className="divider" />

      <div style={{ display: "grid", gridTemplateColumns: "260px 1fr", flex: 1, minHeight: 0 }}>
        {/* category pane */}
        <div style={{ background: "rgba(0,0,0,0.10)", borderRight: "0.5px solid var(--separator)", overflowY: "auto" }}>
          {cats.map(cat => {
            const state = selectionState(cat.id);
            const items = byCat[cat.id] || [];
            const total = items.reduce((a, i) => a + i.size, 0);
            const selCount = items.filter(i => selected.has(i.path)).length;
            const isActive = activeCat === cat.id;
            return (
              <div key={cat.id}
                   onClick={() => setActiveCat(cat.id)}
                   style={{
                     display: "flex", alignItems: "center", gap: 10,
                     padding: "10px 12px",
                     background: isActive ? "rgba(107,82,245,0.18)" : "transparent",
                     borderBottom: "0.5px solid var(--border-hairline)",
                     cursor: "pointer",
                   }}>
                <Checkbox value={state.value} mixed={state.mixed} onChange={() => toggleCat(cat.id)} />
                <Icon name={cat.icon} size={16} color="#FF9F0A" />
                <div style={{ flex: 1, overflow: "hidden" }}>
                  <div style={{ font: "var(--type-body-md)", color: "var(--fg-primary)" }}>{cat.label}</div>
                  <div style={{ font: "var(--type-body-sm)", color: "var(--fg-tertiary)" }}>
                    {selCount > 0 ? `${selCount} of ${items.length} selected` : `${items.length} items`}
                  </div>
                </div>
                <div className="num-md" style={{ color: "var(--fg-tertiary)" }}>{fmt(total)}</div>
              </div>
            );
          })}
        </div>

        {/* detail pane */}
        <div style={{ display: "flex", flexDirection: "column", minHeight: 0 }}>
          <div style={{ padding: "14px 16px 8px" }}>
            <div style={{ font: "var(--type-title-lg)" }}>{cats.find(c => c.id === activeCat)?.label}</div>
            <div style={{ font: "var(--type-body-md)", color: "var(--fg-secondary)", marginTop: 4 }}>
              {cats.find(c => c.id === activeCat)?.rationale}
            </div>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "0 16px 8px" }}>
            <span style={{ font: "var(--type-body-sm)", color: "var(--fg-tertiary)" }}>
              {detailItems.length} items
            </span>
            <div style={{ flex: 1 }} />
            <select value={sort} onChange={e => setSort(e.target.value)}
                    style={{
                      background: "rgba(255,255,255,0.06)", color: "var(--fg-primary)",
                      border: "0.5px solid var(--border-default)", borderRadius: 6,
                      padding: "3px 8px", font: "var(--type-body-sm)"
                    }}>
              {["Size ↓","Size ↑","Modified ↓","Name"].map(s => <option key={s}>{s}</option>)}
            </select>
            <Button onClick={() => toggleCat(activeCat)}>
              {selectionState(activeCat).value ? "Deselect" : "Select all"}
            </Button>
          </div>
          <div className="divider" style={{ margin: 0 }} />

          <div style={{ flex: 1, overflowY: "auto" }}>
            {subgroups.map(g => (
              <div key={g.title}>
                <div style={{
                  display: "flex", alignItems: "center", gap: 8,
                  padding: "8px 16px",
                  background: "rgba(255,255,255,0.02)",
                  borderBottom: "0.5px solid var(--border-hairline)",
                }}>
                  <span style={{ font: "var(--type-title-sm)" }}>{g.title}</span>
                  <div style={{ flex: 1 }} />
                  <span className="num-md" style={{ color: "var(--fg-tertiary)" }}>{fmt(g.total)}</span>
                </div>
                {g.items.map(item => (
                  <div key={item.path} className="list-row" onClick={() => toggle(item.path)}>
                    <Checkbox value={selected.has(item.path)} onChange={() => toggle(item.path)} />
                    <Icon name={item.cat === "Xcode" ? "hammer" : "folder"} size={14} color="#FF9F0A" />
                    <span className="name">{item.name}</span>
                    <Badge kind={item.safety}>{item.safety.toUpperCase()}</Badge>
                    <span className="path">{item.path}</span>
                    <span className="size">{fmt(item.size)}</span>
                  </div>
                ))}
              </div>
            ))}
          </div>
        </div>
      </div>

      {confirm && (
        <div className="confirm-bar">
          <Icon name="alert-triangle" size={18} />
          <div>
            <div style={{ font: "500 13px var(--font-sans)" }}>
              Delete {[...selected].length} items ({fmt(selSize)})?
            </div>
            <div style={{ font: "var(--type-body-sm)", color: "var(--fg-secondary)" }}>
              Cache items are removed directly. Other items move to a 7-day quarantine.
            </div>
          </div>
          <div style={{ flex: 1 }} />
          <Button onClick={() => setConfirm(false)}>Cancel</Button>
          <Button kind="danger" onClick={() => setConfirm(false)}>Delete</Button>
        </div>
      )}

      <div className="action-bar">
        <span style={{ font: "var(--type-body-sm)", color: "var(--fg-secondary)" }}>
          {[...selected].length} of {items.length} selected · {fmt(selSize)}
        </span>
        <div style={{ flex: 1 }} />
        <Button onClick={() => setSelected(new Set(items.map(i => i.path)))}>Select all</Button>
        <Button onClick={() => setSelected(new Set())} disabled={selected.size === 0}>Deselect</Button>
        <Button kind="warning" large onClick={() => setConfirm(true)} disabled={selected.size === 0}>
          Clean {fmt(selSize)}
        </Button>
      </div>
    </div>
  );
}

window.SystemJunk = SystemJunk;
