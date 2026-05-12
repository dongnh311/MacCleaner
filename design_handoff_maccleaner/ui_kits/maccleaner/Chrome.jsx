// =========================================================
// Shared chrome — Icon, Eyebrow, Chip, Badge, Button, Checkbox,
// Toggle, Sparkline, Bar. Pure presentation, no app state.
// Exposes everything on window so other Babel scripts can use it.
// =========================================================
const { useState, useEffect, useMemo, useRef } = React;

// Lucide icon wrapper. We let lucide replace data-lucide={name} after
// React mounts; key on the icon name so React re-renders the slot.
function Icon({ name, size = 16, color, style }) {
  const ref = useRef(null);
  useEffect(() => {
    if (window.lucide && ref.current) {
      ref.current.setAttribute("data-lucide", name);
      ref.current.innerHTML = "";
      window.lucide.createIcons({ icons: window.lucide.icons, attrs: {}, nameAttr: "data-lucide" });
    }
  }, [name]);
  return (
    <i ref={ref}
       data-lucide={name}
       style={{ width: size, height: size, display: "inline-flex", color, ...style }}>
    </i>
  );
}

function Eyebrow({ children, count, style }) {
  return (
    <div className="eyebrow" style={{ display: "flex", alignItems: "baseline", gap: 6, ...style }}>
      <span>{children}</span>
      {count != null && <span className="mono" style={{ color: "var(--fg-quaternary)" }}>{count}</span>}
    </div>
  );
}

function Button({ children, kind = "default", icon, onClick, large = false, style, disabled }) {
  const cls = ["btn"];
  if (kind !== "default") cls.push(kind);
  if (large) cls.push("large");
  return (
    <button className={cls.join(" ")} onClick={onClick} disabled={disabled} style={style}>
      {icon && <Icon name={icon} size={14} />}
      {children}
    </button>
  );
}

function Chip({ children, active, count, onClick }) {
  return (
    <span className={"chip" + (active ? " active" : "")} onClick={onClick}>
      <span>{children}</span>
      {count != null && <span className="mono">{count}</span>}
    </span>
  );
}

function Badge({ kind = "safe", children }) {
  return <span className={"badge " + kind}>{children}</span>;
}

function Checkbox({ value, mixed, onChange }) {
  const state = mixed ? "mixed" : value ? "on" : "";
  return (
    <span
      className={"checkbox " + state}
      onClick={(e) => { e.stopPropagation(); onChange && onChange(!value); }}
      role="checkbox" aria-checked={value}
    />
  );
}

function HeroIconBackdrop({ icon, color = "var(--brand-accent)", size = 56 }) {
  return (
    <div className="hero-icon"
         style={{
           width: size, height: size,
           background: `linear-gradient(135deg, ${color}33, ${color}10)`,
           borderColor: `${color}40`,
           color,
         }}>
      <Icon name={icon} size={Math.round(size * 0.42)} color={color} />
    </div>
  );
}

// Quick sparkline — pass an array of values; renders 100×28 SVG.
function Sparkline({ values, color = "#6B52F5", fill = true, height = 28 }) {
  if (!values || values.length < 2) return null;
  const max = Math.max(...values, 1);
  const stepX = 100 / (values.length - 1);
  const pts = values.map((v, i) => [i * stepX, height - (v / max) * height]);
  const line = "M " + pts.map(p => `${p[0].toFixed(1)},${p[1].toFixed(1)}`).join(" L ");
  const area = line + ` L 100,${height} L 0,${height} Z`;
  const gid = "g" + color.replace("#", "");
  return (
    <svg viewBox={`0 0 100 ${height}`} preserveAspectRatio="none" style={{ width: "100%", height }}>
      <defs>
        <linearGradient id={gid} x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor={color} stopOpacity="0.35" />
          <stop offset="1" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      {fill && <path d={area} fill={`url(#${gid})`} />}
      <path d={line} fill="none" stroke={color} strokeWidth="1.2" />
    </svg>
  );
}

function ModuleHeader({ icon, title, subtitle, accent, trailing }) {
  return (
    <>
      <div className="module-header">
        <HeroIconBackdrop icon={icon} color={accent} />
        <div>
          <div className="module-title">{title}</div>
          <div className="module-subtitle">{subtitle}</div>
        </div>
        <div style={{ flex: 1 }} />
        {trailing}
      </div>
      <div className="divider" />
    </>
  );
}

function bar(value, max, color, label) {
  const pct = Math.max(0, Math.min(100, (value / max) * 100));
  return <div style={{ width: pct + "%", background: color }} title={label} />;
}

Object.assign(window, {
  Icon, Eyebrow, Button, Chip, Badge, Checkbox,
  HeroIconBackdrop, Sparkline, ModuleHeader, bar,
});
