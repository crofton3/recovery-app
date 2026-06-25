const TABS = [
  { key: "today", label: "Today", icon: "◎" },
  { key: "log", label: "Log", icon: "＋" },
  { key: "progress", label: "Progress", icon: "📈" },
  { key: "plan", label: "Plan", icon: "🗒" },
];

export default function BottomNav({ active, onChange }) {
  return (
    <nav className="bottom-nav">
      <div className="nav-inner">
        {TABS.map((t) => (
          <button
            key={t.key}
            className={`nav-btn ${active === t.key ? "active" : ""}`}
            onClick={() => onChange(t.key)}
          >
            <span className="ico">{t.icon}</span>
            <span className="lbl">{t.label}</span>
          </button>
        ))}
      </div>
    </nav>
  );
}
