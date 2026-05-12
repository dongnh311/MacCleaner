// =========================================================
// App container — Window + Sidebar + module router.
// =========================================================
function App() {
  const [active, setActive] = useState("smartCare");
  const mod = window.MODULE_BY_ID[active];
  const sec = window.SECTION_BY_ID[mod.section];

  let body;
  if (active === "smartCare")    body = <SmartCare />;
  else if (active === "systemJunk") body = <SystemJunk />;
  else if (active === "memory")  body = <Memory />;
  else if (active === "sensors") body = <Sensors />;
  else body = <ModulePlaceholder moduleId={active} />;

  return (
    <>
      <Window title={`MacCleaner — ${mod.title}`} accentTint={sec.accent}>
        <div className="split">
          <Sidebar active={active} onSelect={setActive} />
          {body}
        </div>
      </Window>
      <Menubar />
    </>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
