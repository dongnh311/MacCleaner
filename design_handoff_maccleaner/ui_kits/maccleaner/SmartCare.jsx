// =========================================================
// Smart Care — three-pillar overview + floating Clean button.
// Models SmartCareView.swift (phases: idle → scanning → ready).
// =========================================================
function SmartCare() {
  const [phase, setPhase] = useState("idle"); // idle | scanning | ready

  function runScan() {
    setPhase("scanning");
    setTimeout(() => setPhase("ready"), 1400);
  }

  return (
    <div className="module">
      <ModuleHeader
        icon="sparkles"
        title="Smart Care"
        subtitle="Cleanup · Protection · Speed — all in one pass"
        accent="#6B52F5"
        trailing={phase === "ready" && (
          <>
            <span style={{ font: "var(--type-body-sm)", color: "var(--fg-tertiary)", marginRight: 8 }}>
              {new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
            </span>
            <Button icon="refresh-cw" onClick={runScan}>Rescan</Button>
          </>
        )}
      />
      <div style={{ position: "relative", flex: 1, overflow: "hidden" }}>
        {phase === "idle"     && <SCIdle onScan={runScan} />}
        {phase === "scanning" && <SCScanning />}
        {phase === "ready"    && <SCReady />}

        {/* Floating clean / scan FAB lives in every state */}
        <div style={{ position: "absolute", bottom: 20, left: 0, right: 0, display: "flex", justifyContent: "center" }}>
          <button className="fab" onClick={phase === "idle" ? runScan : null}>
            {phase === "scanning" ? "…" : phase === "ready" ? "Clean" : "Scan"}
          </button>
        </div>
      </div>
    </div>
  );
}

function SCIdle({ onScan }) {
  return (
    <div style={{ height: "100%", display: "grid", placeItems: "center", textAlign: "center", padding: 24 }}>
      <div>
        <HeroIconBackdrop icon="sparkles" size={96} color="#6B52F5" />
        <div style={{ font: "600 22px var(--font-sans)", marginTop: 16 }}>Run Smart Care to scan your Mac</div>
        <div style={{ font: "var(--type-body-md)", color: "var(--fg-secondary)", marginTop: 6, maxWidth: 460 }}>
          Inspects junk + trash, malware persistence, and high-memory apps in parallel.
        </div>
      </div>
    </div>
  );
}

function SCScanning() {
  return (
    <div style={{ height: "100%", display: "grid", placeItems: "center" }}>
      <div style={{ textAlign: "center" }}>
        <div className="spinner" style={{
          width: 36, height: 36, border: "3px solid rgba(255,255,255,0.08)",
          borderTopColor: "#6B52F5", borderRadius: "50%", animation: "spin 0.8s linear infinite",
          margin: "0 auto"
        }} />
        <div style={{ font: "var(--type-title-md)", color: "var(--fg-secondary)", marginTop: 16 }}>
          Running all scans…
        </div>
      </div>
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}

function SCReady() {
  return (
    <div style={{ height: "100%", overflowY: "auto", padding: "24px 32px 120px" }}>
      <div className="sc-headline">Alright, here's what I've found.</div>
      <div className="sc-sub">
        Cleanup removes junk, Protection neutralises threats, Speed quits heavy apps. Review each, then hit Run.
      </div>
      <div className="sc-pillars">
        <Pillar kind="cleanup"
                gradient="linear-gradient(160deg,#6B52F5,#199EF5)"
                shadow="rgba(107,82,245,0.35)"
                icon="hard-drive"
                title="Cleanup" subtitle="Removes unneeded junk"
                value="14.2 GB" valueColor="#64D2FF" />
        <Pillar kind="protection"
                gradient="linear-gradient(160deg,#30D158,#5EE0BF)"
                shadow="rgba(48,209,88,0.30)"
                icon="shield-half"
                title="Protection" subtitle="Threats + hidden background apps"
                value="Review" valueColor="#FF9F0A"
                suffix="3 items" />
        <Pillar kind="speed"
                gradient="linear-gradient(160deg,#FF375F,#FF9F0A)"
                shadow="rgba(255,55,95,0.35)"
                icon="gauge"
                title="Speed" subtitle="Quit memory-hungry apps"
                value="6.8 GB" valueColor="#FF375F"
                suffix="in 4 apps" />
      </div>
    </div>
  );
}

function Pillar({ gradient, shadow, icon, title, subtitle, value, valueColor, suffix }) {
  return (
    <div className="pillar">
      <div className="pillar-art" style={{ background: gradient, "--pillar-shadow": shadow }}>
        <Icon name={icon} size={56} color="white" />
      </div>
      <div className="pillar-title">
        <Icon name="alert-circle" size={14} color="#FF9F0A" />
        <span>{title}</span>
      </div>
      <div className="pillar-sub">{subtitle}</div>
      <div className="pillar-value" style={{ color: valueColor }}>{value}</div>
      <div className="pillar-suffix">{suffix || ""}</div>
      <button className="pillar-link">Review Details…</button>
    </div>
  );
}

window.SmartCare = SmartCare;
