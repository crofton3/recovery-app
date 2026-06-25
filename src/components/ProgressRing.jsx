export default function ProgressRing({
  value,
  max,
  size = 96,
  stroke = 9,
  color = "var(--amber)",
  track = "rgba(255,255,255,0.08)",
  centerNum,
  centerLabel,
}) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const pct = max > 0 ? Math.min(1, value / max) : 0;
  const offset = c * (1 - pct);
  return (
    <div className="ring-wrap" style={{ width: size, height: size }}>
      <svg width={size} height={size}>
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={track}
          strokeWidth={stroke}
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={color}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={offset}
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
          style={{ transition: "stroke-dashoffset 0.6s cubic-bezier(0.22,1,0.36,1)" }}
        />
      </svg>
      {(centerNum || centerLabel) && (
        <div className="ring-center">
          <div className="num">{centerNum}</div>
          {centerLabel && <div className="lbl">{centerLabel}</div>}
        </div>
      )}
    </div>
  );
}
